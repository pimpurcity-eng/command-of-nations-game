"""Weapons catalogue in the Call of War / Conflict of Nations style (owner review 2026-10-13).

    python3 tools/rebuild_catalog.py        # rewrites game/data/equipment.json in place

Rules from the owner:
  * nothing is researched at the start except a few weak starter units (limited army);
  * the weakest weapons come first; carriers, bombers, ICBMs and silos come late;
  * research columns use generic category names, not weapon names;
  * one mortar row; each kind of infantry is its own tech; fuller tank and infantry trees
    built from the spare models; drones are their own group (drone factory) incl. Geran-2;
  * a support group (support depot): engineers, bridge layers, recovery, supply, medics;
    mine clearing is retired (there are no mines);
  * infantry vehicles belong to Infantry, air defence to Ordnance.
Owner rule (Oct 12): levels 2 and 4 are upgrades of the level 1 / level 3 model; new models
come at levels 1, 3 and 5.
Existing family ids are kept so saves, tests and the AI keep working; retired families stay
in the file with "retired": true (old saves still load) but are never offered.
"""
import json, copy, os

PATH = os.path.join(os.path.dirname(__file__), "..", "game", "data", "equipment.json")
A = "res://assets/library/arsenal/"
AD = "res://assets/library/airdefense/"
LIB = "res://assets/library/"

def m(stem, base=A):
    return base + stem + ".glb"

def tier(name, model, improvement="", **extra):
    t = {"name": name, "improvement": improvement or "", "model": model}
    t.update(extra)
    return t

UP = "Improved targeting, reliability and combat effectiveness"

def line(*items):
    """items: (name, model) for a new model, or "+" / "+text" for an upgrade of the previous."""
    tiers, last = [], None
    for item in items:
        if isinstance(item, str):
            suffix = item[1:] or "upgrade"
            tiers.append(tier(last[0] + " · " + suffix, last[1], UP))
        else:
            last = item
            tiers.append(tier(item[0], item[1], item[2] if len(item) > 2 else ""))
    assert len(tiers) == 5, tiers
    return tiers

def days(first, step=3):
    return [first + step * i for i in range(5)]

with open(PATH) as f:
    catalog = json.load(f)
by_id = {e["id"]: e for e in catalog}

def family(fid, template=None, **fields):
    """Update an existing family, or create it from a template family."""
    if fid in by_id:
        entry = by_id[fid]
    else:
        entry = copy.deepcopy(by_id[template])
        entry["id"] = fid
        entry["asset_roster_id"] = fid
        entry.pop("retired", None)
        catalog.append(entry)
        by_id[fid] = entry
    entry.update(fields)
    entry.setdefault("starter", False)
    return entry

def retire(fid):
    by_id[fid]["retired"] = True
    by_id[fid]["starter"] = False

BUILDING = {"Infantry": "barracks", "Mechanized": "barracks", "Armor": "tank_plant", "Artillery": "factory",
            "Air defense": "factory", "Missiles": "missile_factory", "Navy": "naval_base", "Drones": "drone_factory",
            "Support": "support_depot", "Fighters": "airbase", "Bombers": "airbase", "Helicopters": "airbase"}

def aa(names, ranges, damages):
    return [dict(t, range=r, damage=d) for t, r, d in zip(names, ranges, damages)]

SHORAD_RANGE, SHORAD_DAMAGE = [1.8, 2.2, 2.5, 2.8, 3.1], [5, 7, 8.5, 10, 11.5]
LRSAM_RANGE, LRSAM_DAMAGE = [3.5, 4.0, 4.4, 4.7, 5.2], [10, 12, 13.5, 15, 16.5]

# ------------------------------------------------------------------------------- RUSSIA
R = "russia"
family("infantry_russia", research_branch="Infantry", name="Infantry", starter=True,
       research_days=days(1), research_tiers=line(("Rifle infantry", m("russia_motor_rifleman")), "+Ratnik kit",
       ("Guards infantry", m("russia_motor_rifleman"), "Better training and night vision"), "+", "+Sotnik kit"))
family("airborne_russia", "infantry_russia", name="Airborne infantry", research_branch="Airborne infantry", starter=False,
       research_days=days(3), research_tiers=line(("VDV paratroopers", m("russia_vdv_paratrooper")), "+", "+air assault", "+", "+guards"))
family("special_forces_russia", "infantry_russia", name="Special forces", research_branch="Special forces", starter=False,
       research_days=days(6), research_tiers=line(("Spetsnaz", m("russia_spetsnaz")), "+", "+raid tactics", "+", "+elite"))
family("naval_infantry_russia", "infantry_russia", name="Naval infantry", research_branch="Naval infantry", starter=False,
       research_days=days(4), research_tiers=line(("Naval infantry", m("russia_naval_infantry")), "+", "+amphibious", "+", "+guards"))
family("snipers_russia", "infantry_russia", name="Snipers", research_branch="Snipers", starter=False,
       research_days=days(1), research_tiers=line(("Sniper team", m("russia_sniper")), "+SV-98", "+thermal optics", "+", "+ASh-12"))
family("apcs_russia", name="Armoured personnel carriers", research_branch="Armoured personnel carrier", starter=True,
       research_days=days(1), research_tiers=line(("BTR-60PB", m("russia_btr60pb")), "+",
       ("BTR-80", m("russia_btr80")), "+", ("BTR-90", m("russia_btr90"))))
family("ifv_russia", "apcs_russia", name="Infantry fighting vehicles", research_branch="Infantry fighting vehicle", starter=False,
       visual_kind="ifv", research_days=days(2), research_tiers=line(("BMP-1", m("russia_bmp1")), "+", ("BMP-2", m("russia_bmp2")), "+",
       ("BMP-3", m("russia_bmp3"))))
family("airborne_ifv_russia", "apcs_russia", name="Airborne fighting vehicles", research_branch="Airborne fighting vehicle", starter=False,
       visual_kind="ifv", research_days=days(5), research_tiers=line(("BMD-2", m("russia_bmd2")), "+", ("BMD-4M", m("russia_bmd4m")), "+", "+advanced"))
family("tanks_russia", name="Main battle tanks", research_branch="Main battle tank", starter=True, research_days=days(1, 4),
       research_tiers=line(("T-62", m("russia_t62")), "+", ("T-72B3", m("russia_t72b3")),
       "+", ("T-90A", m("russia_t90a"))))
family("advanced_tanks_russia", name="Next-generation tanks", research_branch="Next-generation tank", starter=False,
       research_days=days(10), research_tiers=line(("T-80BVM", m("russia_t80bvm")), "+", ("T-90M Proryv", LIB + "t90m_russian.glb"), "+", ("T-14 Armata", m("russia_t14_armata"))))
family("light_tank_russia", "tanks_russia", name="Light tanks", research_branch="Light tank", starter=True, research_days=days(1),
       research_tiers=line(("PL-01 light tank", LIB + "pl01_russian.glb"), "+", "+thermal sights", "+", "+advanced"))
family("2b14_mortar_82_russia", name="Mortars", research_branch="Mortars", starter=True, research_days=days(1),
       research_tiers=line(("2B14 82 mm mortar", m("russia_2b14_mortar_82")), "+", ("2B11 120 mm mortar", m("russia_2b11_mortar_120")), "+", "+guided rounds"))
retire("2b11_mortar_120_russia")
family("d30_howitzer_russia", name="Towed artillery", research_branch="Towed artillery", starter=False, research_days=days(1),
       research_tiers=line(("D-30 howitzer", m("russia_d30_howitzer")), "+", "+modernised", "+", "+guided shells"))
family("artillery_russia", name="Self-propelled artillery", research_branch="Self-propelled artillery", starter=False, research_days=days(4),
       research_tiers=line(("2S1 Gvozdika", m("russia_2s1_gvozdika")), "+",
       ("2S19 Msta-S", m("russia_2s19_msta")), "+", ("2S35 Koalitsiya-SV", m("russia_2s35_koalitsiya"))))
family("skyguard_russia", name="Short-range air defence", research_branch="Short-range air defence", starter=True, research_days=days(1),
       research_tiers=aa(line(("Strela-10", m("russia_strela10", AD)), "+",
       ("Tor-M2", m("russia_tor_m2", AD)), "+", ("Pantsir-S1", m("russia_pantsir_s1"))), SHORAD_RANGE, SHORAD_DAMAGE))
family("patriot_russia", name="Long-range air defence", research_branch="Long-range air defence", starter=False, research_days=days(6, 4),
       research_tiers=aa(line(("Buk-M3", m("russia_buk_m3", AD)), "+", ("S-400 Triumf", m("russia_s400", AD)), "+",
       ("S-500 Prometey", m("russia_s500_prometey", AD))), LRSAM_RANGE, LRSAM_DAMAGE))
family("rockets_russia", name="Rocket artillery", research_branch="Rocket artillery", starter=False, research_days=days(2, 4),
       research_tiers=line(("BM-21 Grad", m("russia_bm21_grad")), "+", ("BM-27 Uragan", m("russia_bm27_uragan")), "+",
       ("BM-30 Smerch", m("russia_bm30_smerch"))))
family("missiles_russia", name="Tactical ballistic missiles", research_branch="Tactical ballistic missile", starter=False, research_days=days(8),
       research_tiers=line(("Iskander-M", m("russia_iskander_m")), "+", "+decoys", "+", "+manoeuvring warhead"))
family("strategic_russia", "missiles_russia", name="Strategic nuclear missiles", research_branch="Strategic nuclear missile", starter=False,
       research_days=days(22), strike_damage=40.0, strike_range=14.0, research_tiers=line(("Topol-M", m("russia_topol_m"), "", ) , "+",
       ("Yars RS-24", m("russia_yars")), "+", "+advanced"))
by_id["strategic_russia"]["research_tiers"][0]["preview"] = A + "russia_topol_m_ready.png"
by_id["strategic_russia"]["research_tiers"][1]["preview"] = A + "russia_topol_m_ready.png"
family("silos_russia", name="Missile silos", research_branch="Missile silo", starter=False, research_days=days(26))
family("coastal_missiles_russia", name="Coastal anti-ship missiles", research_branch="Coastal anti-ship missile", starter=False, research_days=days(9))
family("yak130_russia", name="Light attack aircraft", research_branch="Light attack aircraft", starter=True, research_days=days(1),
       research_tiers=line(("Yak-130", m("russia_yak130")), "+", "+guided bombs", "+", "+advanced"))
family("fighters_russia", name="Air superiority fighters", research_branch="Air superiority fighter", starter=False, research_days=days(4, 4),
       research_tiers=line(("MiG-29SMT", m("russia_mig29smt")), "+", ("Su-35S", m("russia_su35s")), "+", ("Su-57", m("russia_su57"))))
family("strike_russia", "fighters_russia", name="Strike fighters", research_branch="Strike fighter", starter=False, research_days=days(7),
       air_damage=5.0, ground_damage=11.0, research_tiers=line(("Su-34", m("russia_su34")), "+", "+precision bombs", "+", "+advanced"))
family("interceptor_russia", "fighters_russia", name="Interceptors", research_branch="Interceptor", starter=False, research_days=days(9),
       air_damage=13.0, ground_damage=2.0, air_speed=4.0, research_tiers=line(("MiG-31BM", m("russia_mig31bm")), "+", "+R-37M", "+", "+advanced"))
family("bombers_russia", name="Strategic bombers", research_branch="Strategic bomber", starter=False, research_days=days(13),
       research_tiers=line(("Tu-22M3", m("russia_tu22m3")), "+", ("Tu-95MS", m("russia_tu95ms")), "+", ("Tu-160", m("russia_tu160"))))
family("helicopters_russia", name="Attack helicopters", research_branch="Attack helicopter", starter=False, research_days=days(2),
       research_tiers=line(("Mi-24 / Mi-35", m("russia_mi24_mi35")), "+", ("Mi-28N", m("russia_mi28n")),
       "+", ("Ka-52", m("russia_ka52"))))
family("transport_heli_russia", "helicopters_russia", name="Transport helicopters", research_branch="Transport helicopter", starter=False,
       research_days=days(1), ground_damage=2.0, research_tiers=line(("Mi-8 / Mi-17", m("russia_mi8_mi17")), "+", "+armour", "+", "+advanced"))
family("a50u_russia", name="Airborne early warning", research_branch="Airborne early warning", starter=False, research_days=days(15))
family("il76md_russia", name="Transport aircraft", research_branch="Transport aircraft", starter=False, research_days=days(8))
family("drones_russia", name="Reconnaissance drones", research_branch="Reconnaissance drone", starter=True, research_days=days(1),
       ground_damage=1.0, research_tiers=line(("Orlan-10", m("russia_orlan10_drone_only")), "+", "+thermal camera", "+", "+relay"))
family("strike_drone_russia", "drones_russia", name="Strike drones", research_branch="Strike drone", starter=False, research_days=days(5),
       ground_damage=6.0, research_tiers=line(("Forpost", m("russia_forpost")), "+", ("Inokhodets / Orion", m("russia_inokhodets")), "+",
       ("Sirius", m("russia_sirius"))))
family("loitering_russia", name="Loitering munitions", research_branch="Loitering munition", starter=False, research_days=days(4))
family("geran_russia", "loitering_russia", name="One-way attack drones", research_branch="One-way attack drone", starter=False,
       research_days=days(6), air_range=30.0, air_speed=1.6, ground_damage=12.0, model_status="Original model (tools/make_new_models.gd)",
       research_tiers=line(("Geran-2", m("russia_geran2")), "+", "+jam-resistant navigation", "+", "+jet engine"))
for fid, d in [("corvettes_russia", days(1, 4)), ("fleet_russia", days(4, 4)), ("submarines_russia", days(6, 4)),
               ("destroyers_russia", days(8, 4)), ("carriers_russia", days(3, 4))]:
    family(fid, research_days=d, starter=(fid == "corvettes_russia"))
for fid, branch, name, role, d in [("kamaz5350_supply_russia", "Supply truck", "Supply trucks", "supply", days(1)),
                                    ("brem1m_recovery_russia", "Recovery vehicle", "Recovery vehicles", "recovery", days(4)),
                                    ("imr3m_engineer_russia", "Combat engineers", "Combat engineers", "engineer", days(1)),
                                    ("mtu72_bridgelayer_russia", "Bridge layer", "Bridge layers", "bridge", days(5))]:
    family(fid, research_branch=branch, name=name, role=role, research_days=d, starter=False)
family("medic_russia", "imr3m_engineer_russia", name="Field medics", research_branch="Field medics", role="medic", starter=False,
       research_days=days(3), model_status="BTR-80 with medical markings (tools/make_new_models.gd)",
       research_tiers=line(("BMM-80 Simfoniya", m("russia_bmm80_medical")), "+", "+field surgery", "+", "+evacuation"))
retire("ur77_mineclearing_russia")

# ------------------------------------------------------------------------------- UKRAINE
family("infantry_ukraine", research_branch="Infantry", name="Infantry", starter=True, research_days=days(1),
       research_tiers=line(("Rifle infantry", m("euro_fr_foreign_legion")), "+", "+NATO kit", "+", "+night vision"))
family("airborne_ukraine", "infantry_ukraine", name="Airborne infantry", research_branch="Airborne infantry", starter=False, research_days=days(3),
       research_tiers=line(("Air assault troops", m("euro_it_folgore_paratrooper")), "+", "+", "+", "+elite"))
family("special_forces_ukraine", "infantry_ukraine", name="Special forces", research_branch="Special forces", starter=False, research_days=days(6),
       research_tiers=line(("Special operations forces", m("euro_de_ksk")), "+", "+raid tactics", "+", "+elite"))
family("naval_infantry_ukraine", "infantry_ukraine", name="Naval infantry", research_branch="Naval infantry", starter=False, research_days=days(4),
       research_tiers=line(("Marines", m("euro_uk_royal_marine")), "+", "+amphibious", "+", "+elite"))
family("snipers_ukraine", "infantry_ukraine", name="Snipers", research_branch="Snipers", starter=False, research_days=days(1),
       research_tiers=line(("Sniper team", m("euro_fi_winter_sniper")), "+", "+thermal optics", "+", "+long range"))
family("apcs_ukraine", name="Armoured personnel carriers", research_branch="Armoured personnel carrier", starter=True, research_days=days(1),
       research_tiers=line(("VAB", m("euro_vab")), "+", ("Patria AMV", m("euro_patria_amv")), "+", ("Boxer", m("euro_boxer"))))
family("ifv_ukraine", "apcs_ukraine", name="Infantry fighting vehicles", research_branch="Infantry fighting vehicle", starter=False,
       visual_kind="ifv", research_days=days(2), research_tiers=line(("Marder 1A3", m("euro_marder1a3")), "+",
       ("CV9030", m("euro_cv9030")), "+", ("Puma", m("euro_puma"))))
family("tanks_ukraine", name="Main battle tanks", research_branch="Main battle tank", starter=True, research_days=days(1, 4),
       research_tiers=line(("Leopard 1", m("euro_leopard1")), "+", ("Leopard 2A6", m("euro_leopard2a6")),
       "+", ("Challenger 2", m("euro_challenger2"))))
family("advanced_tanks_ukraine", name="Next-generation tanks", research_branch="Next-generation tank", starter=False, research_days=days(10),
       research_tiers=line(("Leclerc", m("euro_leclerc")), "+", ("M1A2 Abrams", LIB + "abrams_european.glb"), "+", ("KF51 Panther", m("euro_kf51_panther"))))
family("light_tank_ukraine", "tanks_ukraine", name="Light tanks", research_branch="Light tank", starter=True, research_days=days(1),
       research_tiers=line(("PL-01 light tank", LIB + "pl01_european.glb"), "+", "+thermal sights", "+", "+advanced"))
family("l16_mortar_81_ukraine", name="Mortars", research_branch="Mortars", starter=True, research_days=days(1),
       research_tiers=line(("L16 81 mm mortar", m("euro_l16_mortar_81")), "+", ("MO-120-RT 120 mm mortar", m("euro_mo120rt_mortar")), "+", "+guided rounds"))
retire("mo120rt_mortar_ukraine")
family("l118_lightgun_ukraine", name="Towed artillery", research_branch="Towed artillery", starter=False, research_days=days(1),
       research_tiers=line(("L118 light gun", m("euro_l118_lightgun")), "+", ("FH70", m("euro_fh70")), "+", "+guided shells"))
family("artillery_ukraine", name="Self-propelled artillery", research_branch="Self-propelled artillery", starter=False, research_days=days(4),
       research_tiers=line(("2S1 Gvozdika (PL)", m("euro_gvozdika_pl")), "+", ("CAESAR", m("euro_caesar")), "+", ("PzH 2000", m("euro_pzh2000"))))
family("skyguard_ukraine", name="Short-range air defence", research_branch="Short-range air defence", starter=True, research_days=days(1),
       research_tiers=aa(by_id["skyguard_ukraine"]["research_tiers"], SHORAD_RANGE, SHORAD_DAMAGE))
family("patriot_ukraine", name="Long-range air defence", research_branch="Long-range air defence", starter=False, research_days=days(6, 4),
       research_tiers=aa(by_id["patriot_ukraine"]["research_tiers"], LRSAM_RANGE, LRSAM_DAMAGE))
family("rockets_ukraine", name="Rocket artillery", research_branch="Rocket artillery", starter=False, research_days=days(2, 4))
family("missiles_ukraine", name="Tactical ballistic missiles", research_branch="Tactical ballistic missile", starter=False, research_days=days(8),
       research_tiers=[dict(t) for t in by_id["missiles_ukraine"]["research_tiers"][:4]] + [tier("Sentinel SR · advanced", m("euro_sentinel_sr"), UP,
       preview=A + "euro_sentinel_sr_ready.png")])
by_id["missiles_ukraine"]["research_tiers"][1]["preview"] = A + "euro_pluton_ready.png"
by_id["missiles_ukraine"]["research_tiers"][3]["preview"] = A + "euro_sentinel_sr_ready.png"
family("strategic_ukraine", "missiles_ukraine", name="Strategic missiles", research_branch="Strategic missile", starter=False,
       research_days=days(22), strike_damage=40.0, strike_range=14.0,
       research_tiers=[tier(n, m("euro_fulgur_ebm"), UP, preview=A + "euro_fulgur_ebm_ready.png") for n in
                       ["Fulgur", "Fulgur · upgrade", "Fulgur · guidance", "Fulgur · guidance · upgrade", "Fulgur · advanced"]])
family("silos_ukraine", name="Missile silos", research_branch="Missile silo", starter=False, research_days=days(26))
family("coastal_missiles_ukraine", name="Coastal anti-ship missiles", research_branch="Coastal anti-ship missile", starter=False, research_days=days(9))
family("hawk_t2_ukraine", name="Light attack aircraft", research_branch="Light attack aircraft", starter=True, research_days=days(1),
       research_tiers=line(("Hawk T2", m("euro_hawk_t2")), "+", "+guided bombs", "+", "+advanced"))
family("fighters_ukraine", name="Air superiority fighters", research_branch="Air superiority fighter", starter=False, research_days=days(4, 4))
family("strike_ukraine", name="Strike fighters", research_branch="Strike fighter", starter=False, research_days=days(7))
family("bombers_ukraine", name="Strategic bombers", research_branch="Strategic bomber", starter=False, research_days=days(13))
family("transport_heli_ukraine", "helicopters_ukraine", name="Transport helicopters", research_branch="Transport helicopter", starter=False,
       research_days=days(1), ground_damage=2.0, research_tiers=line(("Lynx", m("euro_lynx")), "+", ("NH90", m("euro_nh90")), "+",
       ("NH90 Block 2", m("euro_nh90_block2"))))
family("helicopters_ukraine", name="Attack helicopters", research_branch="Attack helicopter", starter=False, research_days=days(2),
       research_tiers=line(("Tiger HAP", m("euro_tiger")), "+", "+Hellfire", "+", "+Tiger Mk III"))
family("a400m_atlas_ukraine", name="Transport aircraft", research_branch="Transport aircraft", starter=False, research_days=days(8))
family("drones_ukraine", name="Reconnaissance drones", research_branch="Reconnaissance drone", starter=True, research_days=days(1),
       ground_damage=1.0, research_tiers=[dict(t, ground_damage=1) for t in line(("Camcopter S-100", m("euro_camcopter_s100")), "+",
       ("Watchkeeper", m("euro_watchkeeper")), "+", "+relay")])
family("strike_drone_ukraine", "drones_ukraine", name="Strike drones", research_branch="Strike drone", starter=False, research_days=days(5),
       ground_damage=6.0, research_tiers=line(("Hermes 450", m("euro_hermes450")), "+", ("Eurodrone", m("euro_eurodrone")), "+", ("nEUROn", m("euro_neuron"))))
family("liutyi_ukraine", "drones_ukraine", name="Long-range attack drones", research_branch="One-way attack drone", starter=False,
       research_days=days(6), air_range=30.0, air_speed=1.8, ground_damage=12.0, single_use=True,
       model_status="Original model (tools/make_new_models.gd)",
       research_tiers=line(("FP-1 / Liutyi", m("ukraine_liutyi")), "+", "+jam-resistant navigation", "+", "+heavier warhead"))
for fid, d in [("corvettes_ukraine", days(1, 4)), ("fleet_ukraine", days(4, 4)), ("submarines_ukraine", days(6, 4)),
               ("destroyers_ukraine", days(8, 4)), ("carriers_ukraine", days(3, 4))]:
    family(fid, research_days=d, starter=(fid == "corvettes_ukraine"))
for fid, branch, name, role, d in [("man_hx77_supply_ukraine", "Supply truck", "Supply trucks", "supply", days(1)),
                                    ("buffel_recovery_ukraine", "Recovery vehicle", "Recovery vehicles", "recovery", days(4)),
                                    ("kodiak_engineer_ukraine", "Combat engineers", "Combat engineers", "engineer", days(1)),
                                    ("leguan_bridgelayer_ukraine", "Bridge layer", "Bridge layers", "bridge", days(5))]:
    family(fid, research_branch=branch, name=name, role=role, research_days=d, starter=False)
family("medic_ukraine", "kodiak_engineer_ukraine", name="Field medics", research_branch="Field medics", role="medic", starter=False,
       research_days=days(3), model_status="Boxer with medical markings (tools/make_new_models.gd)",
       research_tiers=line(("Boxer ambulance", m("euro_boxer_ambulance")), "+", "+field surgery", "+", "+evacuation"))
retire("trojan_breacher_ukraine")

# ------------------------------------------------------------------------------- shared rules
for e in catalog:
    if e.get("retired"):
        continue
    category = e["category"]
    if e["id"].startswith(("strike_drone_", "geran_", "liutyi_", "drones_", "loitering_")):
        category = e["category"] = "Drones"
    building = "airbase" if e["visual_kind"] == "fighter" and category not in ("Drones",) else BUILDING.get(category, "factory")
    e["production_building"] = building
    e["building_requirements"] = {building: 1}
    e.setdefault("research_branch", e["name"])
    # Upkeep follows cost so new families are not free to keep.
    if "upkeep" not in e:
        e["upkeep"] = {"funds": round(e["cost"]["funds"] * 0.1, 1), "fuel": 1.0, "manpower": 0.3}

# Food (owner 2026-10-13, Call of War style): armies eat; infantry-heavy units cost the most food.
for e in catalog:
    e["cost"]["food"] = int(round(e["cost"].get("manpower", 0) * 0.6 + 5))
    e.setdefault("upkeep", {})["food"] = round(max(0.5, e["upkeep"].get("manpower", 0) * 2), 1)

# Economy scale (owner 2026-10-13: "starting resources are too low ... make the units cost a
# little higher"): costs x12 and upkeep x10, with city income x10 and starting stock x30.
for e in catalog:
    for k, v in e["cost"].items():
        e["cost"][k] = int(round(v * 12))
    for k, v in e["upkeep"].items():
        e["upkeep"][k] = round(v * 10, 1)

starters = {}
for e in catalog:
    if e.get("starter"):
        starters.setdefault(e["country"], []).append(e["id"])
with open(PATH, "w") as f:
    json.dump(catalog, f, indent=2, ensure_ascii=False)
    f.write("\n")
live = [e for e in catalog if not e.get("retired")]
print(f"{len(live)} families ({len(catalog) - len(live)} retired); starters:", starters)
