# weather
A bash script that reports the weather from Swedish airports

Note:
-----
Since this script is only applicable in Sweden, the rest of the comments are in Swedish. If you are interested, please email me!

#Funktion
Scriptet tar flygplats som inparameter och läser sedan METAR-strängen från `aro.lfv.se`.

Flygplatsen kan man ange enligt `ICAO`(ESMS), `IATA`(MMX) eller bara flygplatsens namn (”Malmö”).

Följande rapporteras:
 - Temperatur **inklusive** vindavkylning!
 - Vindriktning, både i grader och i bokstäver
 - Relativ fuktighet
 - Lufttryck
