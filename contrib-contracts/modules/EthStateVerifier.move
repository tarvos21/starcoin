address 0xa550c18 {
module ByteUtil {
    use 0x1::Vector;

    public fun slice(data: &vector<u8>, start: u64, end: u64): vector<u8> {
        let i = start;
        let result = Vector::empty<u8>();
        let data_len = Vector::length(data);
        let actual_end = if (end < data_len) {
            end
        } else {
            data_len
        };
        while (i < actual_end){
            Vector::push_back(&mut result, *Vector::borrow(data, i));
            i = i + 1;
        };
        result
    }
}

module EthStateVerifier {
    use 0x1::RLP;
    use 0x1::Vector;
    use 0x1::Hash;
    use 0xa550c18::ByteUtil;

    const INVALID_PROOF: u64 = 400;

    public fun to_nibble(b: u8): (u8, u8) {
        let n1 = b >> 4;
        let n2 = (b << 4) >> 4;
        (n1, n2)
    }

    public fun verify(
        expected_root: vector<u8>,
        key: vector<u8>,
        proof: vector<vector<u8>>,
        expected_value: vector<u8>,
    ): bool {
        let key_index = 0;
        let proof_index = 0;
        let proof_len = Vector::length(&proof);
        while (proof_index < proof_len){
            let node = Vector::borrow(&proof, proof_index);
            let dec = RLP::decode(*node);
            // trie root is always a hash
            if (key_index == 0 || Vector::length(node) >= 32u64) {
                if (Hash::sha3_256(*node) != expected_root) {
                    return false
                }
            } else {
                // and if rlp < 32 bytes, then it is not hashed
                let root = Vector::borrow(&dec, 0);
                if (root != &expected_root) {
                    return false
                }
            };
            let rlp_len = Vector::length(&dec);
            // branch node.
            if (rlp_len == 17) {
                if (key_index >= Vector::length(&key)) {
                    // value stored in the branch
                    let item = Vector::borrow(&dec, 16);
                    if (item == &expected_value) {
                        return true
                    }
                } else {
                    // down the rabbit hole.
                    let index = Vector::borrow(&key, key_index);
                    let new_expected_root = Vector::borrow(&dec, (*index as u64));
                    if (Vector::length(new_expected_root) != 0) {
                        expected_root = *new_expected_root;
                        key_index = key_index + 1;
                        proof_index = proof_index + 1;
                        continue
                    }
                };
            } else if (rlp_len == 2) {
                let node_key = Vector::borrow(&dec, 0);
                let node_value = Vector::borrow(&dec, 1);
                let (prefix, nibble) = to_nibble(*Vector::borrow(node_key, 0));
                if (prefix == 0) {
                    // even extension node
                    let shared_nibbles = ByteUtil::slice(node_key, 1, Vector::length(node_key));
                    let extension_length = Vector::length(&shared_nibbles);
                    if (shared_nibbles ==
                        ByteUtil::slice(&key, key_index, key_index + extension_length)) {
                        expected_root = *node_value;
                        key_index = key_index + extension_length;
                        proof_index = proof_index + 1;
                        continue
                    }
                } else if (prefix == 1) {
                    // odd extension node
                    let shared_nibbles = ByteUtil::slice(node_key, 1, Vector::length(node_key));
                    let extension_length = Vector::length(&shared_nibbles);
                    if (nibble == *Vector::borrow(&key, key_index) &&
                        shared_nibbles ==
                            ByteUtil::slice(
                                &key,
                                key_index + 1,
                                key_index + 1 + extension_length,
                            )) {
                        let _new_expected_root = node_value;
                        expected_root = *node_value;
                        key_index = key_index + 1 + extension_length;
                        proof_index = proof_index + 1;
                        continue
                    }
                } else if (prefix == 2) {
                    // even leaf node
                    let actual_key_left = ByteUtil::slice(node_key, 1, Vector::length(node_key));
                    let key_left = ByteUtil::slice(&key, key_index, Vector::length(&key));
                    return actual_key_left == key_left && &expected_value == node_value
                } else if (prefix == 3) {
                    // odd leaf node
                    return &expected_value == node_value &&
                        nibble == *Vector::borrow(&key, key_index) &&
                        ByteUtil::slice(node_key, 1, Vector::length(node_key)) ==
                            ByteUtil::slice(&key, key_index + 1, Vector::length(&key))
                } else {
                    // invalid proof
                    abort INVALID_PROOF
                };
            };
            return Vector::length(&expected_value) == 0
        };
        abort INVALID_PROOF

        // assert(false, INVALID_PROOF);
    }
}
}