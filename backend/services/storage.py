from appwrite.client import Client
from appwrite.services.storage import Storage
from appwrite.input_file import InputFile
from config import get_settings
import io

settings = get_settings()


def get_appwrite_storage() -> Storage:
    client = Client()
    client.set_endpoint(settings.appwrite_endpoint)
    client.set_project(settings.appwrite_project_id)
    client.set_key(settings.appwrite_api_key)
    return Storage(client)


def upload_file(file_bytes: bytes, filename: str, mime_type: str = "application/octet-stream") -> dict:
    """Upload a file to Appwrite and return file metadata."""
    storage = get_appwrite_storage()
    result = storage.create_file(
        bucket_id=settings.appwrite_bucket_id,
        file_id="unique()",
        file=InputFile.from_bytes(file_bytes, filename, mime_type),
    )
    file_id = result["$id"]
    url = (
        f"{settings.appwrite_endpoint}/storage/buckets/"
        f"{settings.appwrite_bucket_id}/files/{file_id}/view"
        f"?project={settings.appwrite_project_id}"
    )
    return {"file_id": file_id, "url": url}


def delete_file(file_id: str):
    storage = get_appwrite_storage()
    storage.delete_file(bucket_id=settings.appwrite_bucket_id, file_id=file_id)
