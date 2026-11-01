# App Store text

One file per App Store Connect localization: name (30), subtitle (30), keywords (100) and description.
Keywords leave out words already in that locale's name and subtitle, since Apple indexes those anyway.

`en-GB.txt` matches `en-US.txt`. Add English (U.K.) in App Store Connect: the German, French and
Spanish storefronts also search English (U.K.) metadata, so English searches like "adblock" still
find AdVoid there while the local listing covers local words.
