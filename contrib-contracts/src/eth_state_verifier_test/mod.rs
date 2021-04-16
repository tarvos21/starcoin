use anyhow::Result;
use ethereum_types::{H160, H256, U256};

use rlp_derive::{RlpDecodable, RlpEncodable};

use serde::{Deserialize, Serialize};
use starcoin_crypto::HashValue;
use starcoin_executor::execute_readonly_function;
use starcoin_types::account_config::association_address;
use starcoin_types::identifier::Identifier;
use starcoin_types::language_storage::ModuleId;
use starcoin_types::transaction::TransactionPayload;
use starcoin_vm_types::transaction::Package;
use starcoin_vm_types::value::MoveValue;
use starcoin_vm_types::values::VMValueCast;
use test_helper::executor::{association_execute, compile_modules_with_address, prepare_genesis};
use test_helper::Account;

/// Basic account type.
#[derive(Debug, Clone, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct BasicAccount {
    /// Nonce of the account.
    pub nonce: U256,
    /// Balance of the account.
    pub balance: U256,
    /// Storage root of the account.
    pub storage_root: H256,
    /// Code hash of the account.
    pub code_hash: H256,
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EthAccount {
    pub address: H160,
    pub balance: U256,
    pub nonce: U256,
    pub code_hash: H256,
    pub storage_hash: H256,
    pub account_proof: Vec<String>,
    pub storage_proof: Vec<StorageProof>,
}

impl EthAccount {
    pub fn account_value(&self) -> BasicAccount {
        BasicAccount {
            nonce: self.nonce,
            balance: self.balance,
            storage_root: self.storage_hash,
            code_hash: self.code_hash,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct StorageProof {
    pub key: U256,
    pub value: U256,
    pub proof: Vec<String>,
}

#[stest::test]
fn test_eth_state_proof_verify() -> Result<()> {
    let assocation = Account::new_association();
    println!("{}", assocation.address());
    let (chain_state, net) = prepare_genesis();
    // deploy the module
    {
        let source = include_str!("../../modules/EthStateVerifier.move");
        let modules = compile_modules_with_address(association_address(), source);

        let package = Package::new(modules, None)?;
        association_execute(
            net.genesis_config(),
            &chain_state,
            TransactionPayload::Package(package),
        )?;
    }

    {
        // load the example proof response
        let proofs = include_str!("cases/response.json");
        let value: serde_json::Value = serde_json::from_str(proofs)?;
        let account_proof: EthAccount =
            serde_json::from_value(value.get("result").unwrap().clone())?;
        let account_in_rlp = rlp::encode(&account_proof.account_value());
        let proofs: Vec<_> = account_proof
            .account_proof
            .iter()
            .map(|p| hex::decode(&p.as_str()[2..]).unwrap())
            .collect();
        // example use block height: 12247990
        let expected_state_root =
            "0x0fe18577fc7ead5344694c6a830354df38d07551245cf8b8c20719318d417bfb";
        let expected_state_root = MoveValue::vector_u8(hex::decode(&expected_state_root[2..])?);

        let key = {
            let address = account_proof.address.as_bytes().to_vec();
            let hashed_key = HashValue::sha3_256_of(address.as_slice()).to_vec();
            MoveValue::vector_u8(hashed_key)
        };
        let proof = MoveValue::Vector(
            proofs
                .iter()
                .map(|p| MoveValue::vector_u8(p.clone()))
                .collect(),
        );
        let expected_value = MoveValue::vector_u8(account_in_rlp);

        let result = execute_readonly_function(
            &chain_state,
            &ModuleId::new(
                association_address(),
                Identifier::new("EthStateVerifier").unwrap(),
            ),
            &Identifier::new("verify").unwrap(),
            vec![],
            vec![
                expected_state_root.simple_serialize().unwrap(),
                key.simple_serialize().unwrap(),
                proof.simple_serialize().unwrap(),
                expected_value.simple_serialize().unwrap(),
            ],
        )?
        .pop()
        .unwrap()
        .1;
        let is_ok: bool = result.cast().unwrap();
        assert!(is_ok, "verify fail");
    }

    Ok(())
}
