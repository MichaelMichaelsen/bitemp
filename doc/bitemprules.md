# Rules to be checked for Bitemporalitet

This is the list of checks done by the tool checkbitemp.pl. The rules are numbered and if violated, then reported with the rule number

## Rules to be checked

1. RegistreringstidFra must be present - not null
2. VirkningstidFra must be present - not null
3. Status must exists
4. RegistreringstidTil must be greather than RegistreringstidFra (if RegistreingstidTil is present)
5. VirkningstidTil must be greatther than VirkningstidFra (if VirkningtidTil is present)
6. No time overlap for Registreringstid (same key)
7. No duplicates
8. RegisteringtidTil must be present for the last instance
9. No Overlappen registreringstidsintervaller
