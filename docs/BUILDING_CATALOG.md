# Building catalog

All buildings have three levels. New buildings start unbuilt; the four original buildings retain their starting levels. Costs below are base costs for level 1 and level 2. Level 3 costs 1.5× each resource, rounded upward. Construction is a separate queue from unit production.

| Building | Color | Base game hours | Funds / materials / electronics / fuel / personnel | Effect |
|---|---|---:|---|---|
| Military factory | Terracotta | 2 | 200 / 100 / 30 / 20 / 20 | Each level above 1 increases this city’s unit production speed by 25%. |
| Industrial complex | Sand gold | 3 | 240 / 120 / 20 / 30 / 25 | Each level above 1 increases this city’s income of all five resources by 25%. |
| Research center | Purple | 4 | 300 / 100 / 70 / 15 / 20 | Capital only. Each level above 1 increases national research speed by 25%. Two research slots. |
| Airbase | Slate blue | 3 | 220 / 110 / 45 / 30 / 20 | Enables fighter production and provides a home base. Each extra level reduces refueling time by 25%. |
| Financial office | Gold | 2 | 180 / 90 / 20 / 15 / 15 | Each level increases this city’s funds income by 25%. |
| Materials works | Copper | 2 | 180 / 90 / 20 / 15 / 15 | Each level increases this city’s materials income by 25%. |
| Electronics factory | Teal | 2 | 180 / 90 / 20 / 15 / 15 | Each level increases this city’s electronics income by 25%. |
| Fuel depot | Olive green | 2 | 180 / 90 / 20 / 15 / 15 | Each level increases this city’s fuel income by 25%. |
| Recruitment centre | Blue | 2 | 180 / 90 / 20 / 15 / 15 | Each level increases this city’s manpower income by 25%. |
| Barracks | Khaki | 2 | 180 / 100 / 15 / 15 / 40 | Each level increases mechanized / infantry production speed by 25%. |
| Tank plant | Rust red | 3 | 280 / 170 / 45 / 45 / 30 | Each level increases armored-unit production speed by 25%. |
| Naval base | Ocean blue | 4 | 320 / 180 / 55 / 60 / 35 | Coastal cities only. Each level increases ship production speed by 25%. |
| Bunkers | Concrete gray | 3 | 220 / 180 / 20 / 20 / 25 | Each level reduces incoming damage to friendly ground units within 0.6 of a controlled city by 20%, up to 60%. |
| Infrastructure | Ochre | 2 | 200 / 140 / 25 / 20 / 30 | Each level increases this city’s construction speed by 15%. |

Level 3 has twice the base construction work. Infrastructure applies to real construction progress; its displayed ETA should use `BuildingSystem.construction_time`. Factory and specialist production multipliers combine multiplicatively. Resource facility bonuses multiply the existing city industry and specialty bonuses. Province resource-site income is unchanged.

The scene wrappers reuse four existing warehouse models. No model files or source geometry are added. `colour` fields give Claude the same palette for city-screen previews. Existing previews remain the original recovered images until the screen renderer uses that palette.
