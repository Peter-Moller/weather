#!/bin/bash

# Copyright (c) 2015, Peter Möller
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Version 2.0
# Greppa vädret från Sturup (ESMS)
# 2011-05-04 / Peter Möller
# Institutionen för Datavetenskap, Lunds universitet

# En typisk sträng ser ut så här:
# ESMS 230950Z 17009KT CAVOK 16/14 Q1013

# Läs om detta på:
# https://flygskolan.com/flygvaeder-taf-metar-volmet/
# Detta script använder METAR - Meteorological actual report
# Man skulle kunna använda TAF - Terminal Area/Aerodrome Forecast
# Men det får bli en framtida utveckling…
# 2011-09-21: lagt till relativ fuktighet
# 2012-08-22: fixat fel teckenkodning från durl till sed
# 2012-11-05: fixat fel i tidssträngen
# 2012-11-06: Återinfört Aerodrome och lagt till lista över flygplatser
# 2012-12-14: Lagt in IATA-koder (tillsammans med de tidigare ICAO-koderna). 
#             Båda går nu att använda
# 2015-05-05: Ny URL
#             Man kan nu ange flygplats även med namn, t.ex. 'Malmö' eller 'sturup'
#             Not: anger man stad tas den första träffen i denna fil!
#
# Uppdatering:
# Man kan hämta en avkodad METAR för alla flygplatser via denna adress:
# http://weather.noaa.gov/pub/data/observations/metar/decoded/ESMS.TXT


usage()
{
cat << EOF
användning: $0 optioner

Detta script hämtar väder från en Svensk flygplats.
(https://aro.lfv.se/Links/Link/ViewLink?TorLinkId=314&type=MET)

OPTIONER:
  -h      Visa detta meddelande
  -m      Visa METAR-strängen
  -f      Flygplats
EOF
}

fetch_new=f
flygplats=""
metar=f

Reset="\e[0m"
ESC="\e["
RES="0"
BoldFace="1"
ItalicFace="3"
UnderlineFace="4"
SlowBlink="5"
RedBack="41"
RedFont="31"
GreenFont="32"
YellowFont="33"
BlueFont="36"
WhiteFont="37"
FormatString="%-12s%7s%7s"

# Find where the script resides -- without trailing slash
# Get the DirName and ScriptName
if [ -L "${BASH_SOURCE[0]}" ]; then
   # Get the *real* directory of the script
   ScriptDirName="$(dirname "$(readlink "${BASH_SOURCE[0]}")")"   # ScriptDirName='/usr/local/bin'
   # Get the *real* name of the script
   ScriptName="$(basename "$(readlink "${BASH_SOURCE[0]}")")"     # ScriptName='moodle_backup.sh'
else
   ScriptDirName="$(dirname "${BASH_SOURCE[0]}")"
   # What is the name of the script?
   ScriptName="$(basename "${BASH_SOURCE[0]}")"
fi
ScriptFullName="${ScriptDirName}/${ScriptName}"

Svenska_flygplatser="$ScriptDirName/Svenska_flygplatser.txt"

# Datumsträng. Ta bort minutvärdet så att vi inte hämtar data flera gånger om det är samma 10-minutersspann
DateStr="$(date +%F_%H.%M | cut -c-15)"                                        # Ex: DateStr=2024-12-16_10.3
METARfile="/tmp/METAR_${DateStr}.txt"                                          # Ex: METARfile=/tmp/METAR_2024-12-16_10.3.txt 
# Vädret ändrades i maj 2012, här en ny adress som förhoppningsvis fungerar:
METAR_Sverige="https://aro.lfv.se/Links/Link/ViewLink?TorLinkId=314&type=MET"

while getopts "hmf:" OPTION
do
    case $OPTION in
        h)  usage
            exit 1;;
        m)  metar=t;;
        f)  flygplats=$OPTARG;;
        ?)  usage
            exit;;
    esac
done

if [ -z "$flygplats" ]; then
    echo "Du måste ange en option; \"-u\" (uppgradera) eller \"-f flygplats\""
    echo "Avslutar..."
    exit 1
fi


#==============================================================================================================
#   _____ _____ ___  ______ _____    ___________   ______ _   _ _   _ _____ _____ _____ _____ _   _  _____
#  /  ___|_   _/ _ \ | ___ \_   _|  |  _  |  ___|  |  ___| | | | \ | /  __ \_   _|_   _|  _  | \ | |/  ___|
#  \ `--.  | |/ /_\ \| |_/ / | |    | | | | |_     | |_  | | | |  \| | /  \/ | |   | | | | | |  \| |\ `--.
#   `--. \ | ||  _  ||    /  | |    | | | |  _|    |  _| | | | | . ` | |     | |   | | | | | | . ` | `--. \
#  /\__/ / | || | | || |\ \  | |    \ \_/ / |      | |   | |_| | |\  | \__/\ | |  _| |_\ \_/ / |\  |/\__/ /
#  \____/  \_/\_| |_/\_| \_| \_/     \___/\_|      \_|    \___/\_| \_/\____/ \_/  \___/ \___/\_| \_/\____/
#


# Kolla så att det är en giltig flygplats
# Exempel: 'MMX  ESMS  Malmö/Sturup'
#           IATA ICAO  aerodrome
#            1     2    3
check_valid_airport() {
    if [ -n "$flygplats" ]; then
        FlygRad="$(grep -i "$flygplats" "$Svenska_flygplatser")"                   # Ex: FlygRad=$'MMX\tESMS\tMalmö Airport (Sturup)' 
        # Ex: FlygRad='ESKN/NYO Stockholm/Skavsta'
        if [ -z "$FlygRad" ]; then
            echo "Okänd flygplats. Leta efter korrekta koder på:"
            echo "https://sv.wikipedia.org/wiki/Lista_över_flygplatser_i_Sverige"
            echo "Avslutar..."
            exit 1
        fi
        # Tag fram Aerodrome (=namnet på flygplatsen)
        Aerodrome="$(echo "$FlygRad" | cut -d$'\t' -f3)"                           # Ex: Aerodrome='Malmö Airport (Sturup)' 
        # Tag fram ICAO och IATA-koder
        IATA="$(echo "$FlygRad" | awk '{print $1}')"                               # Ex: IATA=MMX
        ICAO="$(echo "$FlygRad" | awk '{print $2}')"                               # Ex: ICAO=ESMS
    fi
}


# Hämta vädret
download_weather_data() {
    if [ ! -r "$METARfile" ]; then
        curl -s "$METAR_Sverige" | iconv --from-code=ISO-8859-1 --to-code=UTF-8 | sed -E 's/<[^>]*>//g' | grep -EA1 "^\s*E[A-Z]{3}\s" | sed 's/^\ *//' | grep -Ev "^--$" > "$METARfile"
    fi
    
    ERR=$?
    if [ "$ERR" -ne 0 ] ; then
        echo "Could not connect to \"$METAR_Sverige\""
        echo "Exiting..."
        exit 1
    else
        WeatherString="$(grep -A1 $ICAO "$METARfile" | tail -1 | sed 's/^\ *//g' | iconv --from-code=ISO-8859-1 --to-code=UTF-8 | cut -d\> -f2 | cut -d\= -f1)"
        if [ -z "$WeatherString" ]; then
            echo "Ingen METAR tillgänglig från ${IATA:-$ICAO} ($Aerodrome). Försök igen senare."
            echo "Avslutar..."
            exit 1
        fi
        # Ex: 
        # 211150Z 22015KT 9999 FEW016 SCT041 BKN049 16/13 Q1016
        # 291120Z 06013KT 9999 SCT014 BKN019 BKN034 09/07 Q1010 REDZ
        # 160920Z 27020KT CAVOK 09/03 Q1011
    fi
}


# Tag fram vindriktning och vindhastighet
get_wind_data() {
    WindDirection="$(echo $WeatherString | grep -oE "\b[^\ >]*KT\b" | cut -c 1-3 | sed 's/^0//g')"
    # Undvik "VRB", d.v.s. variabel riktning vid mycket svaga vindar. Antag då 0°
    if [ "$WindDirection" = "VRB" ]; then
        Angle="N"
        WindDirection=0
    else
        Angle="N"
        (( "$WindDirection" > 22 )) && Angle="NÖ"
        (( "$WindDirection" > 77 )) && Angle="Ö"
        (( "$WindDirection" > 112 )) && Angle="SÖ"
        (( "$WindDirection" > 157 )) && Angle="S"
        (( "$WindDirection" > 202 )) && Angle="SV"
        (( "$WindDirection" > 247 )) && Angle="V"
        (( "$WindDirection" > 292 )) && Angle="NV"
        (( "$WindDirection" > 337 )) && Angle="N"
    fi
    WindSpeed_kt="$(echo $WeatherString | grep -oE "\b[^\ >]*KT\b" | cut -c 4-5)"
    WindSpeed_ms="$(echo "$WindSpeed_kt / 2" | bc)"
}


# Temperatur – ta hand om minusgrader (M)
get_temperature() {
    Temperature_tmp="$(echo $WeatherString | grep -oE \ M?[0-9]\{2\}\/M?[0-9]\{2\}\ | cut -d\/ -f1 | sed 's/^\ //g' | sed 's/^0//g')"
    if [ "$(echo $Temperature_tmp | grep "^M")" ]; then
        Temperature="-$(echo $Temperature_tmp | cut -c 2-3 | sed 's/^0//g')"
    else
        Temperature="$(echo $Temperature_tmp | sed 's/^0//g')"
    fi
    if [ -z "$Temperature" ]; then
        Temperature=0
    fi
}


# Daggpunkt - ta hand om minusgrader för den med
get_dew_point() {
    Daggpunkt_tmp="$(echo $WeatherString | grep -oE \ M?[0-9]\{2\}\/M?[0-9]\{2\}\ | cut -d\/ -f2 | sed 's/^\ //g' | sed 's/^0//g')"
    if [ "$(echo $Daggpunkt_tmp | grep "^M")" ]; then
        Daggpunkt="-$(echo $Daggpunkt_tmp | cut -c 2-3 | sed 's/^0//g')"
    else
        Daggpunkt="$(echo $Daggpunkt_tmp | sed 's/^0//g')"
    fi
    if [ -z "$Daggpunkt" ]; then
        Daggpunkt=0
    fi
    
    # Räkna ut den relativa fuktigheten
    # Formlernas ursprung är oklart.
    # Länk med information om just METAR-tolkning: http://domotics.free.fr/upload/dogm_creeimagemeteolight
    # Site med mera info: http://www.gorhamschaffler.com/humidity_formulas.htm
    # Lista med metereologiska formler: http://www.aprweather.com/pages/calc.htm
    
    # Utnyttja att x^y == e^(y*log(x))
    
    # Man använder olika faktorer beroende på om temperaturen är under eller över noll
    # Först: räkna ut täljaren (baserad på temperaturen). Olika faktorer för minus och plusgrader
    if [ "${Temperature%?}" = "-" ]; then
        A=7.6
        B=240.7
    else
        A=7.5
        B=237.3
    fi
    sddt="$(echo "6.1078 * e( ( $A * $Temperature ) / ( $B + $Temperature ) * l(10) )" | bc -l)"
    
    # Sedan: nämnaren (baserad på daggpunkten). Olika faktorer för minus och plusgrader
    if [ "${Daggpunkt%?}" = "-" ]; then
        A=7.6
        B=240.7
    else
        A=7.5
        B=237.3
    fi
    sddtd="$(echo "6.1078 * e( ( $A * $Daggpunkt ) / ( $B + $Daggpunkt ) * l(10) )" | bc -l)"
    
    # Nu kan vi räkna ut den relativa fuktigheten:
    RelFuktighet="$(echo "scale=2; $sddtd / $sddt * 100" | bc -l | cut -d. -f1)"
}


get_time() {
    TimeString="$(echo $WeatherString | grep -oE "^[0-9]{6}Z\ " | grep -oE "....Z\ $" | sed 's/\ $//g')"
    
    # Tiden i METAR är i UTC. Detta måste fixas för den lokala tiden
    # Kontrollera om sommartid är aktivt (date +%z get "+0200")
    if [ "$(date +%z | cut -c 3)" = "2" ]; then
        # Sommartid: addera 2 timmar
        TimeH="$(echo "$(echo $TimeString | cut -c 1-2) + 2" | bc)"
    else
        # Vintertid: addera 1 timma
        TimeH="$(echo "$(echo $TimeString | cut -c 1-2) + 1" | bc)"
    fi
    TimeM="$(echo $TimeString | cut -c 3-4)"
}


get_air_pressure() {
    Pressure="$(echo $WeatherString | grep -oE \ Q[0-9]\{4\}| cut -c 3-6)"
}

get_wind_chill() {
    # Räkna ut vindavkylning (enligt  http://sv.wikipedia.org/wiki/Vindavkylning)
    # 13.126667 + 0.6215 * $Temperatur - 13.924748 * $WindSpeed_ms^0.16 + 0.4875195 * $Temperatur * $WindSpeed_ms^0.16
    # Undvik vindhastighet på 0 m/s
    if [ "$WindSpeed_ms" = "0" ]; then
        Vindavkylning_stilla="$Temperature"
    else
        Vindavkylning_stilla="$(echo "13.126667 + 0.6215 * $Temperature - 13.924748 * e( 0.16 * l($WindSpeed_ms) ) + 0.4875195 * $Temperature * e( 0.16 * l($WindSpeed_ms) )" | bc -l | cut -d\. -f1)"
    fi
    [[ -z "$Vindavkylning_stilla" ]] && Vindavkylning_stilla="0"
    
    # 1 grad =    0.0174532925 radianer
    # 1 radian = 57.2957795130 grader
    # Räkna med cykelhastighet på 5 m/s, d.v.s. 18 km/h
    BicycleSpeed=5
    Windspeed_Eastward="$(echo "$BicycleSpeed + ( $WindSpeed_ms * s( $WindDirection * 0.0174532925 ) )" | bc -l)"
    Windspeed_Westward="$(echo "$BicycleSpeed - ( $WindSpeed_ms * s( $WindDirection * 0.0174532925 ) )" | bc -l)"
    #Vindavkylning_Westward="$(echo "13.126667 + 0.6215 * $Temperature - 13.924748 * e( 0.16 * l($Windspeed_Westward) ) + 0.4875195 * $Temperature * e( 0.16 * l($Windspeed_Westward) )" | bc -l | cut -d\. -f1)"
    
    # Om man har vind i ryggen (negativ vind) så är avkylningen samma som temperaturen vid vindstilla
    if [ "$(expr $Windspeed_Eastward \< 1)" = "0" ]; then 
        Vindavkylning_Eastward="$(echo "13.126667 + 0.6215 * $Temperature - 13.924748 * e( 0.16 * l($Windspeed_Eastward) ) + 0.4875195 * $Temperature * e( 0.16 * l($Windspeed_Eastward) )" | bc -l)"
    else
        Vindavkylning_Eastward="$Temperature"
    fi
    
    if [ "$(expr $Windspeed_Westward \< 1)" = "0" ]; then 
        Vindavkylning_Westward="$(echo "13.126667 + 0.6215 * $Temperature - 13.924748 * e( 0.16 * l($Windspeed_Westward) ) + 0.4875195 * $Temperature * e( 0.16 * l($Windspeed_Westward) )" | bc -l)"
    else
        Vindavkylning_Westward="$Temperature"
    fi
}


print_results() {
    printf "${ESC}${BoldFace};${UnderlineFace}mVädret på $Aerodrome:${Reset} (${IATA:-$ICAO}; kl $TimeH:$TimeM)\n"
    if [ "$metar" = "t" ]; then
        echo "$WeatherString"
    fi
    printf "${FormatString}\n" "Temperatur:" "${Temperature}°C" " (${Vindavkylning_stilla}°C)"
    printf "%-12s%7s%-2s%-10s\n" "Vind:" "$WindSpeed_ms m/s" " " "Riktn: $Angle (${WindDirection}°)"
    if [ "$ICAO" = "ESMS" ]; then
        printf "${FormatString}\n" "Till Lund:" "$(echo "scale=0; ($Windspeed_Westward * 10 + 5) / 10" | bc -l) m/s" " ($(echo "scale=0; ($Vindavkylning_Westward * 10 + 5) / 10" | bc -l)°C)"
        printf "${FormatString}\n" "Till Sandby:" "$(echo "scale=0; ($Windspeed_Eastward * 10 + 5) / 10" | bc -l) m/s" " ($(echo "scale=0; ($Vindavkylning_Eastward * 10 + 5) / 10" | bc -l)°C)"
    fi
    printf "${FormatString}\n" "Rel.fuktighet:" "$RelFuktighet % " " "
    echo "Lufttryck: $Pressure hPa"
    printf "${ESC}${ItalicFace}m(temperatur inom parentes är vindavkylning)$Reset\n"
}

#
#   _____ _   _______    ___________   ______ _   _ _   _ _____ _____ _____ _____ _   _  _____
#  |  ___| \ | |  _  \  |  _  |  ___|  |  ___| | | | \ | /  __ \_   _|_   _|  _  | \ | |/  ___|
#  | |__ |  \| | | | |  | | | | |_     | |_  | | | |  \| | /  \/ | |   | | | | | |  \| |\ `--.
#  |  __|| . ` | | | |  | | | |  _|    |  _| | | | | . ` | |     | |   | | | | | | . ` | `--. \
#  | |___| |\  | |/ /   \ \_/ / |      | |   | |_| | |\  | \__/\ | |  _| |_\ \_/ / |\  |/\__/ /
#  \____/\_| \_/___/     \___/\_|      \_|    \___/\_| \_/\____/ \_/  \___/ \___/\_| \_/\____/
#
#==============================================================================================================

check_valid_airport
download_weather_data
get_wind_data
get_temperature
get_dew_point
get_time
get_air_pressure
get_wind_chill

print_results
