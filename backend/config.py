from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str
    firebase_service_account_path: str = "./firebase-service-account.json"
    appwrite_endpoint: str
    appwrite_project_id: str
    appwrite_api_key: str
    appwrite_bucket_id: str
    agent_private_key: str
    polygon_rpc_url: str = "https://rpc-amoy.polygon.technology"
    contract_address: str
    secret_key: str
    environment: str = "development"

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings():
    return Settings()
