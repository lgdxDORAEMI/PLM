import unittest
from pathlib import Path

from app.services.routine.meal_catalog import (
    attach_meal_images,
    attach_recommendation_image,
    image_path_for,
    load_meal_catalog,
    public_image_url,
)
from app.services.routine.prompt import MEAL_TITLES


class MealCatalogTest(unittest.TestCase):
    def test_twenty_unique_titles_have_existing_frontend_assets(self) -> None:
        catalog = load_meal_catalog()
        items = [item for values in catalog.values() for item in values]
        self.assertEqual(set(catalog), {"breakfast", "lunch", "dinner", "snack"})
        self.assertTrue(all(len(catalog[period]) == 5 for period in catalog))
        self.assertEqual(len(items), 20)
        self.assertEqual(len({item["title"] for item in items}), 20)
        self.assertEqual(set(MEAL_TITLES), {item["title"] for item in items})

        root = Path(__file__).resolve().parents[2] / "supabase" / "storage" / "meal-images"
        for item in items:
            image_path = item["payload"]["imagePath"]
            self.assertTrue((root / image_path).is_file(), f"missing image: {image_path}")
            self.assertEqual(image_path_for(item["title"]), image_path)

    def test_routine_and_chat_card_receive_same_asset(self) -> None:
        routine = {
            "meal": [{
                "item_key": "meal:lunch",
                "title": "연어구이와 현미밥",
                "payload": {"period": "lunch"},
                "source_ids": [],
            }]
        }
        expected = "lunch/grilled_salmon_brown_rice.jpg"
        enriched = attach_meal_images(routine)
        self.assertEqual(enriched["meal"][0]["payload"]["imagePath"], expected)
        with self.subTest("public URL"):
            self.assertEqual(
                public_image_url(expected, "https://example.supabase.co/"),
                "https://example.supabase.co/storage/v1/object/public/meal-images/lunch/grilled_salmon_brown_rice.jpg",
            )
        card = attach_recommendation_image({"title": "연어구이와 현미밥"})
        self.assertEqual(card["imagePath"], expected)


if __name__ == "__main__":
    unittest.main()
