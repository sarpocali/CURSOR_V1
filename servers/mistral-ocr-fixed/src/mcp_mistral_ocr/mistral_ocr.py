import os
import json
import base64
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime
from urllib.parse import urlparse

from mistralai import Mistral

class MistralOCRProcessor:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.max_file_size = 50 * 1024 * 1024  # 50MB in bytes

    def _save_result(self, result: Dict[str, Any], source_name: str, output_dir: Path) -> None:
        """Save OCR result to output directory with timestamp"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = output_dir / f"{source_name}_{timestamp}.json"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)

    def _process_response(self, response) -> str:
        """Convert OCR response to JSON string"""
        return json.dumps(response.model_dump(), ensure_ascii=False)

    async def process_local_file(self, file_path: Path, output_dir: Path) -> str:
        """Process a local file using Mistral's OCR capabilities"""
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")

        # Check file size
        file_size = file_path.stat().st_size
        if file_size > self.max_file_size:
            raise ValueError(f"File size exceeds 50MB limit: {file_size / 1024 / 1024:.2f}MB")

        file_extension = file_path.suffix.lower()

        client = Mistral(api_key=self.api_key)
        
        try:
            if file_extension in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                # Handle image files with base64 encoding
                base64_image = self._encode_image(file_path)
                if not base64_image:
                    raise ValueError("Failed to encode image")

                response = client.ocr.process(
                    model="mistral-ocr-latest",
                    document={
                        "type": "image_url",
                        "image_url": f"data:image/jpeg;base64,{base64_image}"
                    }
                )
            else:
                # Handle PDF and other document types
                uploaded_file = client.files.upload(
                    file={
                        "file_name": file_path.name,
                        "content": open(file_path, "rb"),
                    },
                    purpose="ocr"
                )

                # Get signed URL for processing
                signed_url = client.files.get_signed_url(file_id=uploaded_file.id)

                # Process the document
                response = client.ocr.process(
                    model="mistral-ocr-latest",
                    document={
                        "type": "document_url",
                        "document_url": signed_url.url,
                    }
                )

            # Convert response to JSON string
            result = self._process_response(response)
            
            # Save result to output directory
            source_name = file_path.stem
            self._save_result(json.loads(result), source_name, output_dir)
            return result

        except Exception as e:
            raise Exception(f"Error processing file with Mistral API: {str(e)}")

    async def process_url_file(self, url: str, file_type: str, output_dir: Path) -> str:
        """Process a file from a URL using Mistral's OCR capabilities"""
        try:
            if file_type not in ["image", "pdf"]:
                raise ValueError("file_type must be either 'image' or 'pdf'")

            client = Mistral(api_key=self.api_key)
            response = client.ocr.process(
                model="mistral-ocr-latest",
                document={
                    "type": "image_url" if file_type == "image" else "document_url",
                    f"{'image' if file_type == 'image' else 'document'}_url": url
                }
            )

            # Convert response to JSON string
            result = self._process_response(response)

            # Extract filename from URL
            parsed_url = urlparse(url)
            source_name = Path(parsed_url.path).stem or 'url_document'
            
            # Save result to output directory
            self._save_result(json.loads(result), source_name, output_dir)
            return result

        except Exception as e:
            raise Exception(f"Error processing URL with Mistral API: {str(e)}")

    def _encode_image(self, image_path: Path) -> Optional[str]:
        """Encode an image file to base64."""
        try:
            with open(image_path, "rb") as image_file:
                return base64.b64encode(image_file.read()).decode('utf-8')
        except Exception as e:
            print(f"Error encoding image: {e}")
            return None
