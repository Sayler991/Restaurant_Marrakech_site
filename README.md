# Restaurant Marrakech — Tlemcen (maquette de démonstration)

Site vitrine d'une page avec tableau de bord pour le **Restaurant Marrakech** (78 Lotissement Korso, bd Imama, Mansourah, Tlemcen). C'est une **maquette de démonstration**, non officielle (mention en pied de page).

- Site : https://sayler991.github.io/Restaurant_Marrakech_site/
- Espace patron : https://sayler991.github.io/Restaurant_Marrakech_site/admin/
- Dossier prospect : `/workspace/prospects/restaurant_marrakech.md`

## Faits réels utilisés (sources publiques, relevées le 15/10/2026)
- **Fiche Google** (miroir exa.ai/library/place/8hchth61170) :
  - adresse ; GPS 34.878824, -1.342188 ; téléphone +213 674 82 27 11 ;
  - horaires midi et soir ; **4,0/5 sur 762 avis** ;
  - Facebook https://facebook.com/1838022142909638 ;
  - 3 avis cités tels quels (en anglais), datés.
- **Petit Futé** : « cuisine traditionnelle algérienne », couscous, tajines, méchoui, hrira ; couscous à commander la veille ; décor d'arabesques dorées ; 2 500–3 500 DA le repas complet.
- **Avis Tripadvisor et Google** : pastilla/bastilla, tajine hlou, tajine l'ham (agneau et boulettes), foie mchermel, salades, thé à la menthe, cocktails, pas d'alcool.

## Provisoire / à confirmer avec le client
- **Aucun prix publié** : la carte liste les plats cités sans prix et affiche « Carte à venir ». Le patron ajoute les prix dans l'admin.
- **Vendredi midi** : la donnée Google est incohérente. Le site affiche le vendredi soir seulement (18h–23h30).
- Un second numéro (+213 656 86 10 70) et un e-mail figurent sur Tripadvisor ; ils ne sont pas utilisés.
- Réservations (paramètres de la maquette) :
  - créneaux de 30 min : midi 11h00–15h30, soir 18h00–22h30 ;
  - 1 à 20 personnes, jusqu'à 60 jours à l'avance ;
  - contrôlées côté serveur.

## Photos : uniquement des photos libres de droits (aucune photo Google/Facebook/Tripadvisor)
Les photos sont légendées « Illustration » sur le site. Converties en WebP + AVIF (800 et 1600 px).

| Fichier | Sujet | Source / licence |
|---|---|---|
| tajine | Tajine d'agneau aux olives | Pexels, Hiroko Nakagawa — https://www.pexels.com/photo/delicious-moroccan-tagine-with-lamb-and-olives-37369301/ |
| tajine-legumes | Tajine et petits plats | Pexels — https://www.pexels.com/photo/cooked-food-on-a-clay-pot-4502970/ |
| riad | Cour de riad | Pexels — https://www.pexels.com/photo/interior-of-the-riad-palais-sebban-marrakesh-morocco-15531325/ |
| the-plateau | Théière et verres colorés | Pexels, MAG Photography — https://www.pexels.com/photo/traditional-moroccan-tea-set-with-multicolored-glasses-32547854/ |
| the-verre | Verre à thé ciselé | Pexels, Constanze Marie — https://www.pexels.com/photo/traditional-moroccan-tea-set-with-ornate-designs-31567514/ |
| the-service | Thé versé | Pexels — https://www.pexels.com/photo/pouring-moroccan-mint-tea-in-glass-36157389/ |
| lanterne | Lanterne ajourée | Unsplash — https://unsplash.com/photos/ornate-moroccan-lantern-hanging-from-a-ceiling-mG38cwFEG_4 |
| lanternes | Lanternes colorées | Unsplash, mathieu gauzy — https://unsplash.com/photos/a-person-stands-amidst-a-colorful-display-of-moroccan-lanterns-ZGBiE0WRk3Q |

- Les licences Pexels et Unsplash permettent l'usage libre, commercial compris, sans attribution obligatoire. Les auteurs non nommés n'ont pas pu être lus (pages protégées).
- Plan © contributeurs OpenStreetMap.
- Polices : Fraunces + Outfit (SIL OFL).

## Technique
Base reprise de Café Dib v2 :
- animations : Ken Burns, titre lettre à lettre, apparitions au défilement, traits dorés, bandeau défilant ; `prefers-reduced-motion` respecté ;
- contenu en direct depuis Supabase avec `content.json` en secours ;
- tableau de bord : réservations, messages, clients, stats, contenu, carte et prix, horaires midi et soir, photos, historique ;
- alertes : temps réel, son, notification.

SEO : title et meta description, canonical, Open Graph, JSON-LD `Restaurant` (données réelles uniquement), sitemap.xml, robots.txt, textes alt, `lang="fr"`.

## Supabase
Projet `rvreusugrtiubqtafgbk`, schéma **`marrakech`** :
- appliquer `supabase/schema.sql` puis `seed.sql` ;
- RLS : lecture publique du contenu, envoi anonyme limité aux colonnes autorisées, tout le reste réservé au propriétaire `public.is_owner()` (benduy0@gmail.com, table partagée `public.owners`) ;
- anti-abus : pot de miel, statut forcé, horaires, 60 jours max, 20 demandes par minute, 3 par téléphone par 10 min ;
- schémas exposés : liste existante + `marrakech`.

## Tests
```
node tools/e2e/e2e.js https://sayler991.github.io/Restaurant_Marrakech_site/ /workspace/marrakech_shots/
```

## v2 (16/10/2026) — vraies photos
État précédent : tags `v1` (main) et `v1-gh-pages`. Note Google mise à jour : 4,0/5 sur 762 avis. Carte : ajout Bourek, Brochettes, Tajine aux pruneaux & amandes, Tajine de boulettes aux olives (vus sur les photos clients), sans prix — aucune carte avec prix trouvée (Petit Futé, Tripadvisor, TripTap, WinNaklou, exa.ai).
Photos clients Google Maps (`/workspace/marrakech_real/gm_*`) converties en WebP + AVIF 800 + pleine taille (fichiers `-1600`, plafonnés à la taille source) : hero = salle (puis porte, tajine pruneaux, tablée) ; « La maison » = salle + porte ; carte = hrira (soupes & entrées), tajine pruneaux (tajines) ; galerie = salle, porte, bourek, brochettes, tajine boulettes, tablée. Restent en illustration libre : the-plateau (onglet Thé), the-service (bandeau + réservation).
