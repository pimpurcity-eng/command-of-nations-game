#!/usr/bin/env python3
"""Writes game/translations/ui.csv (owner request 2026-10-12: translations).

Godot translates any button, label or menu item whose text equals a key below (auto-translate),
so the key is the English text itself. Languages: Russian, Ukrainian, German, French, Spanish.
Add rows here and rerun; Godot imports the CSV into one .translation file per language.
"""
import csv
import os
import sys

LANGS = ["ru", "uk", "de", "fr", "es"]
# English: [ru, uk, de, fr, es]
T = {
    "START CAMPAIGN": ["НАЧАТЬ КАМПАНИЮ", "ПОЧАТИ КАМПАНІЮ", "KAMPAGNE STARTEN", "LANCER LA CAMPAGNE", "INICIAR CAMPAÑA"],
    "START NEW CAMPAIGN": ["НОВАЯ КАМПАНИЯ", "НОВА КАМПАНІЯ", "NEUE KAMPAGNE", "NOUVELLE CAMPAGNE", "NUEVA CAMPAÑA"],
    "CONTINUE CAMPAIGN": ["ПРОДОЛЖИТЬ КАМПАНИЮ", "ПРОДОВЖИТИ КАМПАНІЮ", "KAMPAGNE FORTSETZEN", "CONTINUER LA CAMPAGNE", "CONTINUAR CAMPAÑA"],
    "REGIONAL CAMPAIGN": ["РЕГИОНАЛЬНАЯ КАМПАНИЯ", "РЕГІОНАЛЬНА КАМПАНІЯ", "REGIONALE KAMPAGNE", "CAMPAGNE RÉGIONALE", "CAMPAÑA REGIONAL"],
    "Play as Ukraine": ["Играть за Украину", "Грати за Україну", "Als Ukraine spielen", "Jouer l'Ukraine", "Jugar como Ucrania"],
    "Play as Russia": ["Играть за Россию", "Грати за Росію", "Als Russland spielen", "Jouer la Russie", "Jugar como Rusia"],
    "ALL WEAPONS TEST MAP": ["КАРТА ВСЕГО ОРУЖИЯ", "КАРТА ВСІЄЇ ЗБРОЇ", "TESTKARTE ALLER WAFFEN", "CARTE DE TOUTES LES ARMES", "MAPA DE TODAS LAS ARMAS"],
    "EUROPE MAP · 20 PLAYERS (PREVIEW)": ["КАРТА ЕВРОПЫ · 20 ИГРОКОВ (ПРЕДПРОСМОТР)", "КАРТА ЄВРОПИ · 20 ГРАВЦІВ (ПЕРЕГЛЯД)", "EUROPAKARTE · 20 SPIELER (VORSCHAU)", "CARTE D'EUROPE · 20 JOUEURS (APERÇU)", "MAPA DE EUROPA · 20 JUGADORES (AVANCE)"],
    "WORLD MAP · 100 PLAYERS (PREVIEW)": ["КАРТА МИРА · 100 ИГРОКОВ (ПРЕДПРОСМОТР)", "КАРТА СВІТУ · 100 ГРАВЦІВ (ПЕРЕГЛЯД)", "WELTKARTE · 100 SPIELER (VORSCHAU)", "CARTE DU MONDE · 100 JOUEURS (APERÇU)", "MAPA MUNDIAL · 100 JUGADORES (AVANCE)"],
    "LOADING EUROPE…": ["ЗАГРУЗКА ЕВРОПЫ…", "ЗАВАНТАЖЕННЯ ЄВРОПИ…", "EUROPA WIRD GELADEN…", "CHARGEMENT DE L'EUROPE…", "CARGANDO EUROPA…"],
    "LOADING WORLD…": ["ЗАГРУЗКА МИРА…", "ЗАВАНТАЖЕННЯ СВІТУ…", "WELT WIRD GELADEN…", "CHARGEMENT DU MONDE…", "CARGANDO EL MUNDO…"],
    "MUSIC: ON": ["МУЗЫКА: ВКЛ", "МУЗИКА: УВІМК", "MUSIK: AN", "MUSIQUE : OUI", "MÚSICA: SÍ"],
    "MUSIC: OFF": ["МУЗЫКА: ВЫКЛ", "МУЗИКА: ВИМК", "MUSIK: AUS", "MUSIQUE : NON", "MÚSICA: NO"],
    "SOUND: ON": ["ЗВУК: ВКЛ", "ЗВУК: УВІМК", "TON: AN", "SON : OUI", "SONIDO: SÍ"],
    "SOUND: OFF": ["ЗВУК: ВЫКЛ", "ЗВУК: ВИМК", "TON: AUS", "SON : NON", "SONIDO: NO"],
    "Music: ON": ["Музыка: вкл", "Музика: увімк", "Musik: an", "Musique : oui", "Música: sí"],
    "Music: OFF": ["Музыка: выкл", "Музика: вимк", "Musik: aus", "Musique : non", "Música: no"],
    "Sound: ON": ["Звук: вкл", "Звук: увімк", "Ton: an", "Son : oui", "Sonido: sí"],
    "Sound: OFF": ["Звук: выкл", "Звук: вимк", "Ton: aus", "Son : non", "Sonido: no"],
    "Doctrine: country default": ["Доктрина: по умолчанию", "Доктрина: за замовчуванням", "Doktrin: Landesstandard", "Doctrine : par défaut", "Doctrina: predeterminada"],
    "Play": ["Играть", "Грати", "Start", "Jouer", "Jugar"],
    "Pause": ["Пауза", "Пауза", "Pause", "Pause", "Pausa"],
    "Stop": ["Стоп", "Стоп", "Halt", "Stop", "Alto"],
    "Split": ["Разделить", "Розділити", "Teilen", "Diviser", "Dividir"],
    "Attack": ["Атака", "Атака", "Angriff", "Attaque", "Atacar"],
    "Move": ["Двигаться", "Рух", "Bewegen", "Déplacer", "Mover"],
    "Armies": ["Армии", "Армії", "Armeen", "Armées", "Ejércitos"],
    "More": ["Ещё", "Ще", "Mehr", "Plus", "Más"],
    "AT WAR": ["ВОЙНА", "ВІЙНА", "IM KRIEG", "EN GUERRE", "EN GUERRA"],
    "PEACE": ["МИР", "МИР", "FRIEDEN", "PAIX", "PAZ"],
    "Retreat": ["Отступить", "Відступити", "Rückzug", "Retraite", "Retirada"],
    "Reset north": ["Север вверх", "Північ угору", "Norden ausrichten", "Nord en haut", "Norte arriba"],
    "Rotate left": ["Повернуть влево", "Повернути ліворуч", "Nach links drehen", "Tourner à gauche", "Girar a la izquierda"],
    "Rotate right": ["Повернуть вправо", "Повернути праворуч", "Nach rechts drehen", "Tourner à droite", "Girar a la derecha"],
    "Terrain / borders": ["Рельеф / границы", "Рельєф / кордони", "Gelände / Grenzen", "Terrain / frontières", "Terreno / fronteras"],
    "Speed 1x": ["Скорость 1x", "Швидкість 1x", "Tempo 1x", "Vitesse 1x", "Velocidad 1x"],
    "Speed 2x": ["Скорость 2x", "Швидкість 2x", "Tempo 2x", "Vitesse 2x", "Velocidad 2x"],
    "Speed 4x": ["Скорость 4x", "Швидкість 4x", "Tempo 4x", "Vitesse 4x", "Velocidad 4x"],
    "Save game": ["Сохранить игру", "Зберегти гру", "Spiel speichern", "Sauvegarder", "Guardar partida"],
    "Load game": ["Загрузить игру", "Завантажити гру", "Spiel laden", "Charger", "Cargar partida"],
    "Equipment & production": ["Техника и производство", "Техніка та виробництво", "Ausrüstung & Produktion", "Équipement et production", "Equipo y producción"],
    "Army roster": ["Список армий", "Список армій", "Armeeliste", "Liste des armées", "Lista de ejércitos"],
    "New match": ["Новый матч", "Новий матч", "Neues Spiel", "Nouvelle partie", "Nueva partida"],
    "Add destination to selected army": ["Добавить точку маршрута", "Додати точку маршруту", "Ziel zur Armee hinzufügen", "Ajouter une destination", "Añadir destino al ejército"],
    "Merge nearby friendly armies": ["Объединить соседние армии", "Об'єднати сусідні армії", "Nahe Armeen vereinen", "Fusionner les armées proches", "Unir ejércitos cercanos"],
    "Split selected units": ["Разделить выбранные части", "Розділити вибрані частини", "Einheiten aufteilen", "Diviser les unités", "Dividir unidades"],
    "Army composition / battle info": ["Состав армии / бой", "Склад армії / бій", "Armee / Gefechtsinfo", "Composition / combat", "Composición / combate"],
    "Technology / day unlocks": ["Технологии / открытия по дням", "Технології / відкриття за днями", "Technologie / Freischaltungen", "Technologies / déblocages", "Tecnología / desbloqueos"],
    "Capital / construction": ["Столица / строительство", "Столиця / будівництво", "Hauptstadt / Bau", "Capitale / construction", "Capital / construcción"],
    "Supply exchange": ["Биржа снабжения", "Біржа постачання", "Versorgungsbörse", "Bourse d'approvisionnement", "Bolsa de suministros"],
    "All weapon models": ["Все модели оружия", "Усі моделі зброї", "Alle Waffenmodelle", "Tous les modèles d'armes", "Todos los modelos de armas"],
    "Select several armies": ["Выбрать несколько армий", "Вибрати кілька армій", "Mehrere Armeen wählen", "Choisir plusieurs armées", "Elegir varios ejércitos"],
    "Fire control": ["Управление огнём", "Керування вогнем", "Feuerleitung", "Contrôle du tir", "Control de fuego"],
    "Attack enemy army": ["Атаковать армию врага", "Атакувати армію ворога", "Feindarmee angreifen", "Attaquer l'armée ennemie", "Atacar al ejército enemigo"],
    "Victory progress": ["Ход к победе", "Шлях до перемоги", "Siegesfortschritt", "Progrès vers la victoire", "Progreso hacia la victoria"],
    "Diplomacy": ["Дипломатия", "Дипломатія", "Diplomatie", "Diplomatie", "Diplomacia"],
    "Delay / synchronize arrival": ["Задержка / синхронное прибытие", "Затримка / синхронне прибуття", "Verzögern / gleichzeitig ankommen", "Retarder / synchroniser", "Retrasar / sincronizar llegada"],
    "Forced march": ["Форсированный марш", "Форсований марш", "Gewaltmarsch", "Marche forcée", "Marcha forzada"],
    "Upgrade selected army": ["Модернизировать армию", "Модернізувати армію", "Armee modernisieren", "Moderniser l'armée", "Modernizar ejército"],
    "Rebase aircraft": ["Перебазировать авиацию", "Перебазувати авіацію", "Flugzeuge verlegen", "Redéployer l'aviation", "Rebasar aviones"],
    "Player account": ["Аккаунт игрока", "Акаунт гравця", "Spielerkonto", "Compte joueur", "Cuenta de jugador"],
    "War newspaper": ["Военная газета", "Воєнна газета", "Kriegszeitung", "Journal de guerre", "Periódico de guerra"],
    "Battle reports": ["Боевые сводки", "Бойові зведення", "Gefechtsberichte", "Rapports de bataille", "Partes de batalla"],
    "Retreat selected army": ["Отвести армию", "Відвести армію", "Armee zurückziehen", "Retirer l'armée", "Retirar ejército"],
    "Annex selected province": ["Аннексировать провинцию", "Анексувати провінцію", "Provinz annektieren", "Annexer la province", "Anexionar provincia"],
    "Doctrine & strategic weapons": ["Доктрина и стратегическое оружие", "Доктрина та стратегічна зброя", "Doktrin & strategische Waffen", "Doctrine et armes stratégiques", "Doctrina y armas estratégicas"],
    "Army details": ["Сведения об армии", "Відомості про армію", "Armeedetails", "Détails de l'armée", "Detalles del ejército"],
    "Attack enemy": ["Атаковать врага", "Атакувати ворога", "Feind angreifen", "Attaquer l'ennemi", "Atacar al enemigo"],
    "Add destination": ["Добавить точку", "Додати точку", "Ziel hinzufügen", "Ajouter une étape", "Añadir destino"],
    "Merge nearby": ["Объединить рядом", "Об'єднати поруч", "In der Nähe vereinen", "Fusionner", "Unir cercanos"],
    "Split units": ["Разделить части", "Розділити частини", "Einheiten teilen", "Diviser", "Dividir unidades"],
    "Select armies": ["Выбрать армии", "Вибрати армії", "Armeen wählen", "Choisir des armées", "Elegir ejércitos"],
    "Delay / sync arrival": ["Задержка / синхронно", "Затримка / синхронно", "Verzögern / synchron", "Retarder / synchro", "Retrasar / sincronizar"],
    "Upgrade army": ["Модернизировать", "Модернізувати", "Modernisieren", "Moderniser", "Modernizar"],
    "Victory": ["Победа", "Перемога", "Sieg", "Victoire", "Victoria"],
    "News": ["Новости", "Новини", "Nachrichten", "Actualités", "Noticias"],
    "Battles": ["Бои", "Бої", "Gefechte", "Batailles", "Batallas"],
    "Arsenal": ["Арсенал", "Арсенал", "Arsenal", "Arsenal", "Arsenal"],
    "Close": ["Закрыть", "Закрити", "Schließen", "Fermer", "Cerrar"],
    "VICTORY PROGRESS": ["ПУТЬ К ПОБЕДЕ", "ШЛЯХ ДО ПЕРЕМОГИ", "SIEGESFORTSCHRITT", "PROGRÈS VERS LA VICTOIRE", "PROGRESO HACIA LA VICTORIA"],
    "WAR NEWSPAPER": ["ВОЕННАЯ ГАЗЕТА", "ВОЄННА ГАЗЕТА", "KRIEGSZEITUNG", "JOURNAL DE GUERRE", "PERIÓDICO DE GUERRA"],
    "BATTLE REPORTS": ["БОЕВЫЕ СВОДКИ", "БОЙОВІ ЗВЕДЕННЯ", "GEFECHTSBERICHTE", "RAPPORTS DE BATAILLE", "PARTES DE BATALLA"],
    "DIPLOMACY": ["ДИПЛОМАТИЯ", "ДИПЛОМАТІЯ", "DIPLOMATIE", "DIPLOMATIE", "DIPLOMACIA"],
    "COALITION": ["КОАЛИЦИЯ", "КОАЛІЦІЯ", "KOALITION", "COALITION", "COALICIÓN"],
    "MESSAGES": ["СООБЩЕНИЯ", "ПОВІДОМЛЕННЯ", "NACHRICHTEN", "MESSAGES", "MENSAJES"],
    "DOCTRINES": ["ДОКТРИНЫ", "ДОКТРИНИ", "DOKTRINEN", "DOCTRINES", "DOCTRINAS"],
    "STRATEGIC WEAPONS": ["СТРАТЕГИЧЕСКОЕ ОРУЖИЕ", "СТРАТЕГІЧНА ЗБРОЯ", "STRATEGISCHE WAFFEN", "ARMES STRATÉGIQUES", "ARMAS ESTRATÉGICAS"],
    "Propose peace": ["Предложить мир", "Запропонувати мир", "Frieden anbieten", "Proposer la paix", "Proponer la paz"],
    "Declare war": ["Объявить войну", "Оголосити війну", "Krieg erklären", "Déclarer la guerre", "Declarar la guerra"],
    "Right of way": ["Право прохода", "Право проходу", "Durchmarschrecht", "Droit de passage", "Derecho de paso"],
    "Shared vision": ["Общая разведка", "Спільна розвідка", "Geteilte Sicht", "Vision partagée", "Visión compartida"],
    "Embargo": ["Эмбарго", "Ембарго", "Embargo", "Embargo", "Embargo"],
    "Lift embargo": ["Снять эмбарго", "Зняти ембарго", "Embargo aufheben", "Lever l'embargo", "Levantar embargo"],
    "Create": ["Создать", "Створити", "Gründen", "Créer", "Crear"],
    "Leave coalition": ["Покинуть коалицию", "Вийти з коаліції", "Koalition verlassen", "Quitter la coalition", "Dejar la coalición"],
    "Send": ["Отправить", "Надіслати", "Senden", "Envoyer", "Enviar"],
    "Everyone": ["Всем", "Усім", "Alle", "Tout le monde", "Todos"],
    "Build": ["Построить", "Збудувати", "Bauen", "Construire", "Construir"],
    "Launch at target": ["Пуск по цели", "Пуск по цілі", "Auf Ziel abfeuern", "Tirer sur la cible", "Lanzar al objetivo"],
    "No battles yet.": ["Боёв пока не было.", "Боїв ще не було.", "Noch keine Gefechte.", "Aucune bataille pour l'instant.", "Aún no hay batallas."],
    "No messages yet.": ["Сообщений пока нет.", "Повідомлень ще немає.", "Noch keine Nachrichten.", "Aucun message pour l'instant.", "Aún no hay mensajes."],
    "The first issue is printed at the end of day 1.": ["Первый выпуск выйдет в конце 1-го дня.", "Перший випуск вийде наприкінці 1-го дня.", "Die erste Ausgabe erscheint am Ende von Tag 1.", "Le premier numéro paraît à la fin du jour 1.", "El primer número sale al final del día 1."],
    "Skip": ["Пропустить", "Пропустити", "Überspringen", "Passer", "Omitir"],
    "Research": ["Исследования", "Дослідження", "Forschung", "Recherche", "Investigación"],
    "Russia": ["Россия", "Росія", "Russland", "Russie", "Rusia"],
    "Ukraine": ["Украина", "Україна", "Ukraine", "Ukraine", "Ucrania"],
    "Language: English": ["Язык: English", "Мова: English", "Sprache: English", "Langue : English", "Idioma: English"],
}
LANGUAGE_NAMES = {"en": "English", "ru": "Русский", "uk": "Українська", "de": "Deutsch", "fr": "Français", "es": "Español"}


def main():
    path = os.path.join(sys.argv[1] if len(sys.argv) > 1 else "game", "translations", "ui.csv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["keys", "en"] + LANGS)
        for en, row in T.items():
            assert len(row) == len(LANGS), en
            w.writerow([en, en] + row)
        for code, name in LANGUAGE_NAMES.items():
            key = "Language: " + name
            if key not in T:
                w.writerow([key, key] + [key] * len(LANGS))
    print(path, len(T), "strings")


if __name__ == "__main__":
    main()
