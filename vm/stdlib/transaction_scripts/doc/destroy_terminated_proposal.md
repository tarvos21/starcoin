
<a name="destroy_terminated_proposal"></a>

# Script `destroy_terminated_proposal`






<pre><code><b>public</b> <b>fun</b> <a href="destroy_terminated_proposal.md#destroy_terminated_proposal">destroy_terminated_proposal</a>&lt;<a href="../../modules/doc/Token.md#0x1_Token">Token</a>: <b>copyable</b>, Action&gt;(_signer: &signer, proposer_address: address, proposal_id: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="destroy_terminated_proposal.md#destroy_terminated_proposal">destroy_terminated_proposal</a>&lt;<a href="../../modules/doc/Token.md#0x1_Token">Token</a>: <b>copyable</b>, Action&gt;(
    _signer: &signer,
    proposer_address: address,
    proposal_id: u64,
) {
    <a href="../../modules/doc/Dao.md#0x1_Dao_destroy_terminated_proposal">Dao::destroy_terminated_proposal</a>&lt;<a href="../../modules/doc/Token.md#0x1_Token">Token</a>, Action&gt;(proposer_address, proposal_id);
}
</code></pre>



</details>