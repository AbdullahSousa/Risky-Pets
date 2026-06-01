"""
test_api.py
───────────
Validates the /assess endpoint against the 3 official scenarios from the spec.
Since we can't send a real image in unit tests, this also includes a mock-mode
that patches the inference layer directly.

Usage:
    # Against a running local server (requires a real image):
    python test_api.py --image /path/to/dog.jpg

    # Logic-only unit test (no server needed, patches inference):
    python test_api.py --unit
"""

import argparse
import sys

# ─────────────────────────────────────────────────────────────────────────────
# Unit tests — test the risk formula directly, no server required
# ─────────────────────────────────────────────────────────────────────────────

def run_unit_tests():
    from schemas import AssessmentRequest
    from risk_calculator import calculate_risk

    print("=" * 55)
    print("  Risk Calculator Unit Tests")
    print("=" * 55)

    scenarios = [
        {
            "name": "Scenario A — High-Risk Zoonotic Bite",
            "disease": "Ringworm",
            "confidence": 0.90,
            "request": AssessmentRequest(
                interaction_type="bite",
                broke_skin=True,
                deep_puncture=True,
                lesion_oozing=False,
                rabies_signs=False,
            ),
            "expected_score": 120.0,
            "expected_level": "CRITICAL",
        },
        {
            "name": "Scenario B — Moderate-Risk Scratch",
            "disease": "Dermatitis",
            "confidence": 0.80,
            "request": AssessmentRequest(
                interaction_type="scratch",
                broke_skin=True,
                deep_puncture=False,
                lesion_oozing=True,
                rabies_signs=False,
            ),
            "expected_score": 43.5,
            "expected_level": "MODERATE",
        },
        {
            "name": "Scenario C — Low-Risk Touch",
            "disease": "Flea_Allergy",
            "confidence": 0.95,
            "request": AssessmentRequest(
                interaction_type="touch",
                broke_skin=False,
                deep_puncture=False,
                lesion_oozing=False,
                rabies_signs=False,
            ),
            "expected_score": 4.75,
            "expected_level": "LOW",
        },
        {
            "name": "Scenario D — Rabies Critical Override",
            "disease": "Healthy",
            "confidence": 0.99,
            "request": AssessmentRequest(
                interaction_type="touch",
                broke_skin=False,
                deep_puncture=False,
                lesion_oozing=False,
                rabies_signs=True,
            ),
            "expected_level": "CRITICAL",
        },
    ]

    all_passed = True
    for s in scenarios:
        result = calculate_risk(s["request"], s["disease"], s["confidence"])
        score_ok = (
            "expected_score" not in s
            or abs(result["final_risk_score"] - s["expected_score"]) < 0.01
        )
        level_ok = result["risk_level"] == s["expected_level"]
        passed = score_ok and level_ok

        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"\n{status}  {s['name']}")
        print(f"       Score : {result['final_risk_score']}"
              + (f"  (expected {s['expected_score']})" if "expected_score" in s else ""))
        print(f"       Level : {result['risk_level']}  (expected {s['expected_level']})")
        print(f"       Action: {result['user_action']}")

        if not passed:
            all_passed = False

    print("\n" + "=" * 55)
    print("  All tests passed ✅" if all_passed else "  Some tests FAILED ❌")
    print("=" * 55)
    return all_passed


# ─────────────────────────────────────────────────────────────────────────────
# Integration test — hits the running server with a real image
# ─────────────────────────────────────────────────────────────────────────────

def run_integration_test(image_path: str, api_url: str = "http://localhost:8080"):
    import requests

    print(f"\n🔍  Integration test against {api_url}")

    # Health check
    r = requests.get(f"{api_url}/health")
    assert r.status_code == 200, f"Health check failed: {r.text}"
    print("✅  Health check passed")

    # Assessment
    with open(image_path, "rb") as f:
        files = {"image": (image_path, f, "image/jpeg")}
        data = {
            "interaction_type": "bite",
            "broke_skin": "true",
            "deep_puncture": "true",
            "lesion_oozing": "false",
            "rabies_signs": "false",
        }
        r = requests.post(f"{api_url}/assess", files=files, data=data)

    if r.status_code == 200:
        result = r.json()
        print("✅  /assess response:")
        for k, v in result.items():
            print(f"    {k}: {v}")
    else:
        print(f"❌  Error {r.status_code}: {r.text}")


# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit", action="store_true", help="Run formula unit tests (no server needed)")
    parser.add_argument("--image", type=str, help="Path to an image for integration test")
    parser.add_argument("--url", type=str, default="http://localhost:8080", help="API base URL")
    args = parser.parse_args()

    if args.unit:
        ok = run_unit_tests()
        sys.exit(0 if ok else 1)
    elif args.image:
        run_integration_test(args.image, args.url)
    else:
        print("Usage:\n  python test_api.py --unit\n  python test_api.py --image dog.jpg")
