# weather
A bash script that reports the weather from Swedish airports

Note:
-----
Since this script is only applicable in Sweden, the rest of the comments are in Swedish. If you are interested, please email me!

#Funktion
Scriptet tar flygplats som inparameter och läser sedan METAR-strängen från `aro.lfv.se`. En METAR-sträng ser ut som `ESMS 230950Z 17009KT CAVOK 16/14 Q1013` och det är väl kryptiskt, varför detta script finns. Dessa uppgifter uppdateras två gånger i timmen av personal på flygplatsen eller (på mindre flygplatser) av automatiska avläsare.

Flygplatsen kan anges enligt `ICAO`(”ESMS”), `IATA`(”MMX”) eller bara flygplatsens namn (”Malmö”).

Följande rapporteras:
 - Temperatur **inklusive** vindavkylning!
 - Vindriktning, både i grader och i bokstäver
 - Relativ fuktighet
 - Lufttryck


#Optioner
`-f *flygplats*` anger vilken flygplats man får rapportering om  
`-u` uppdaterar scriptet till senaste version  
`-d` slår på debug-information
