from web3 import Web3
from config import get_settings
import json
import os

settings = get_settings()

# ABI — only the functions we call from the backend
CONTRACT_ABI = [
    {
        "inputs": [
            {"internalType": "string",  "name": "plotId",       "type": "string"},
            {"internalType": "bytes32", "name": "documentHash", "type": "bytes32"}
        ],
        "name": "registerPlot",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "string", "name": "plotId", "type": "string"}],
        "name": "verifyPlot",
        "outputs": [
            {"internalType": "bytes32", "name": "documentHash", "type": "bytes32"},
            {"internalType": "uint256", "name": "timestamp",    "type": "uint256"},
            {"internalType": "address", "name": "registeredBy", "type": "address"},
            {"internalType": "bool",    "name": "exists",       "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "string",  "name": "plotId",      "type": "string"},
            {"internalType": "bytes32", "name": "hashToCheck", "type": "bytes32"}
        ],
        "name": "validateHash",
        "outputs": [{"internalType": "bool", "name": "isValid", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    }
]


class BlockchainService:
    def __init__(self):
        self.w3 = Web3(Web3.HTTPProvider(settings.polygon_rpc_url))
        self.account = self.w3.eth.account.from_key(settings.agent_private_key)
        self.contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(settings.contract_address),
            abi=CONTRACT_ABI
        )

    def is_connected(self) -> bool:
        return self.w3.is_connected()

    def hash_document(self, pdf_bytes: bytes) -> bytes:
        """Compute SHA-256 hash of PDF bytes, return as bytes32."""
        import hashlib
        return hashlib.sha256(pdf_bytes).digest()

    def anchor_plot(self, plot_id: str, pdf_bytes: bytes) -> dict:
        """
        Write document hash to blockchain.
        Returns tx_hash and document_hash hex string.
        """
        doc_hash = self.hash_document(pdf_bytes)
        doc_hash_bytes32 = doc_hash  # 32 bytes exact

        nonce = self.w3.eth.get_transaction_count(self.account.address)
        gas_price = self.w3.eth.gas_price

        txn = self.contract.functions.registerPlot(
            plot_id,
            doc_hash_bytes32
        ).build_transaction({
            "from":     self.account.address,
            "nonce":    nonce,
            "gas":      200000,
            "gasPrice": gas_price,
            "chainId":  80002,  # Polygon Amoy
        })

        signed  = self.w3.eth.account.sign_transaction(txn, settings.agent_private_key)
        tx_hash = self.w3.eth.send_raw_transaction(signed.raw_transaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

        return {
            "tx_hash":       tx_hash.hex(),
            "document_hash": "0x" + doc_hash.hex(),
            "block_number":  receipt.blockNumber,
            "success":       receipt.status == 1,
        }

    def verify_plot(self, plot_id: str) -> dict:
        """Read plot record from blockchain (free — no gas)."""
        doc_hash, timestamp, registered_by, exists = (
            self.contract.functions.verifyPlot(plot_id).call()
        )
        return {
            "exists":        exists,
            "document_hash": "0x" + doc_hash.hex(),
            "timestamp":     timestamp,
            "registered_by": registered_by,
        }


# Singleton
_blockchain_service = None

def get_blockchain_service() -> BlockchainService:
    global _blockchain_service
    if _blockchain_service is None:
        _blockchain_service = BlockchainService()
    return _blockchain_service
