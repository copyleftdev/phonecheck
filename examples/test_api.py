#!/usr/bin/env python3
"""
PhoneCheck API Testing Script

Demonstrates various phone number validation scenarios.
"""

import requests
import json
from typing import Dict, Optional

BASE_URL = "http://localhost:8080"


class PhoneCheckClient:
    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url

    def health_check(self) -> Dict:
        """Check API health status"""
        response = requests.get(f"{self.base_url}/health")
        return response.json()

    def validate(
        self, phone_number: str, region: Optional[str] = None
    ) -> Dict:
        """Validate a phone number"""
        payload = {"phone_number": phone_number}
        if region:
            payload["region"] = region

        response = requests.post(
            f"{self.base_url}/validate",
            json=payload,
            headers={"Content-Type": "application/json"},
        )
        return response.json()


def print_result(label: str, result: Dict):
    """Pretty print validation result"""
    print(f"\n{'=' * 60}")
    print(f"📞 {label}")
    print(f"{'=' * 60}")

    if "error" in result:
        print(f"❌ Error: {result['message']}")
        return

    print(f"✅ Valid: {result['valid']}")
    print(f"📍 Possible: {result['possible']}")
    print(f"📱 Type: {result['type']}")
    print(f"🌍 Country Code: +{result['country_code']}")
    print(f"🔢 National Number: {result['national_number']}")
    print(f"🏳️  Region: {result['region']}")
    print(f"\nFormats:")
    print(f"  E.164: {result['e164_format']}")
    print(f"  International: {result['international_format']}")
    print(f"  National: {result['national_format']}")
    print(f"\nReason: {result['possibility_reason']}")


def main():
    client = PhoneCheckClient()

    print("🚀 PhoneCheck API Test Suite")
    print("=" * 60)

    # Health check
    health = client.health_check()
    print(f"✅ API Status: {health['status']}")
    print(f"📦 Version: {health['version']}")

    # Test cases
    test_cases = [
        ("US Mobile", "+14155552671", None),
        ("US Landline", "+12125551234", "US"),
        ("UK Mobile", "+447911123456", "GB"),
        ("Germany", "+4930123456", "DE"),
        ("Japan", "+81312345678", "JP"),
        ("India", "+919876543210", "IN"),
        ("Australia", "+61291234567", "AU"),
        ("Brazil", "+5511987654321", "BR"),
        ("Invalid (too short)", "+1234", "US"),
        ("Invalid (wrong format)", "123456789", None),
        ("Toll Free US", "+18001234567", "US"),
        ("Premium Rate UK", "+449011234567", "GB"),
    ]

    for label, number, region in test_cases:
        try:
            result = client.validate(number, region)
            print_result(label, result)
        except requests.exceptions.ConnectionError:
            print(f"\n❌ Connection Error: Is the server running?")
            break
        except Exception as e:
            print(f"\n❌ Error testing {label}: {e}")

    print("\n" + "=" * 60)
    print("✅ Test suite complete!")


if __name__ == "__main__":
    main()
