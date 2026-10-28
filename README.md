# Girudo 「ギルド」

A guild management addon for WotLK 3.3.5a. \
Designed for and tested on ChromieCraft.

## Install

Drop the `Girudo` folder in `Interface\AddOns\`.

## Usage

Open the guild window. Girudo opens with it. Close it and Girudo closes too.

- `/girudo` toggles the guild window the same way the keybind does
- Drag the Girudo window to move it. Position is saved.

### Roster

- Nine columns: Level, Class, Name, Location, Last Online, Join Date, Rank, Note, Officer Note
- Click any header to sort. Default is Rank descending.
- Class icons and class-colored names
- Three search boxes: Player, Note, Search All. They stack.
- Show Offline checkbox. Off by default.
- Online and displayed member counts at the top right

Last Online fades as time passes.

Join Date comes from the officer note. The format is `dd.mm.yy by <name>`. Only the date gets used.

Click any row to open the member popup. It shows the member's info and has buttons for promote, demote, target, whisper, invite, kick, and editing the public and officer notes.

### Log

Pulls from Blizzard's guild event log and keeps its own copy. Events Blizzard purges stay in Girudo's log (capped at 2000 entries).

- Merges on every update
- Captures public and officer note changes as they happen
- Search box at the top
- Clear Log button at the bottom
- Sortable by date, action, or details

Action types are Invited, Joined, Left, Promoted, Demoted, Kicked, MOTD Changed, Public Note, and Officer Note. Each has its own color.

Promote and demote entries show the old rank and the new rank. When the old rank can't be worked out it shows `?`. Names are class-colored.

### Other tabs

GB Log, Alts, Macros, Ranks, and Settings are placeholders for now.

## Notes

Some things are limited by the 3.3.5a API.

**Join Date.** The API doesn't expose one. Girudo reads it from the officer note. If it's not there, you get a dash.

**Last Online.** The API gives years, months, days, and hours. It returns `0,0,0,0` for anyone offline under an hour. When Girudo has seen the member online recently it uses its own timestamp to show minutes. Otherwise you see `< 1h`.

**Log times.** Different servers return different data from `GetGuildEventInfo`. Girudo handles both absolute timestamps (year, month, day, hour) and relative ones (days ago, hours ago). If neither works it falls back to scan order.
