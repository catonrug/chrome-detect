#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/chrome-detect.git && cd chrome-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#set name
name=$(echo "Google Chrome")
home=$(echo "https://www.google.co.uk/work/chrome/browser/")

#lets check latest version for exe and msi installer
linklist=$(cat <<EOF
https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BBF2074E4-8356-F8B3-CA3E-6A3D31706CF5%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers/dl/chrome/install/googlechromestandaloneenterprise.msi
https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BBF2074E4-8356-F8B3-CA3E-6A3D31706CF5%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable/dl/chrome/install/googlechromestandaloneenterprise64.msi
https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BCCC2CBDB-3B3D-8579-804A-661B13499EAC%7D%26lang%3Dlv%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dtrue/update2/installers/ChromeStandaloneSetup.exe
https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BCCC2CBDB-3B3D-8579-804A-661B13499EAC%7D%26lang%3Dlv%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dtrue%26ap%3Dx64-stable/update2/installers/ChromeStandaloneSetup64.exe
extra line
EOF
)

#change log location
changes=$(echo "https://en.wikipedia.org/wiki/Google_Chrome_release_history")

printf %s "$linklist" | while IFS= read -r url
do {

rm $tmp/* -rf > /dev/null

#check if file is still there
wget -S --spider -o $tmp/output.log "$url"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" 
if [ $? -eq 0 ]; then
#if there is such thing as Last-Modified
echo

#set filename
filename=$(echo $url | sed "s/^.*\///g")

lastmodified=$(grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" | sed "s/^.*: //")

#check if this last modified file name is in database
grep "$filename $lastmodified" $db
if [ $? -ne 0 ]; then

echo new $name version detected!
echo

#download file
echo Downloading $filename
wget $url -O $tmp/$filename -q

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 2048000 ]; then
echo

echo extracting installer..
7z x $tmp/$filename -y -o$tmp  > /dev/null
echo

#msi installer no not have [102~] file but we want to get one which is inside [Binary.GoogleChromeInstaller]
if [ -f "$tmp/Binary.GoogleChromeInstaller" ]; then
echo extracting Binary.GoogleChromeInstaller..
7z x "$tmp/Binary.GoogleChromeInstaller" -y -o$tmp > /dev/null
echo
fi

version=$(strings "$tmp/102~" | grep "url.*codebase" | sed "s/\//\n/g" | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+")

echo $version | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

wget -qO- "$changes" | grep -A 99 `echo "$version" | sed "s/\.[0-9]\+//3"` | grep -B99 -m1 "</tr>" | grep -m99 -A99 "<ul" | sed -e "s/<[^>]*>//g" | grep -v "^$" | sed "s/\[.*\]//g" | sed -e "/:$/! s/^/- /" > $tmp/change.log
#https://stackoverflow.com/questions/11958369/sed-replace-only-if-string-exists-in-current-line

#check if even something has been created
if [ -f $tmp/change.log ]; then

#calculate how many lines log file contains
lines=$(cat $tmp/change.log | wc -l)
if [ $lines -gt 0 ]; then
echo change log found:
echo
cat $tmp/change.log
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$filename $lastmodified">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

case "$filename" in
*64.msi)
type=$(echo "(64-bit) msi")
;;
*64.exe)
type=$(echo "(64-bit)")
;;
*msi)
type=$(echo "(32-bit) msi")
;;
*exe)
type=$(echo "(32-bit)")
;;
esac

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version $type" "$url 
$md5
$sha1

`cat $tmp/change.log`"
} done
echo

else
#changes.log file has created but changes is mission
echo changes.log file has created but changes is mission
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log file has created but changes is mission: 
$version 
$changes "
} done
fi

else
#changes.log has not been created
echo changes.log has not been created
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "changes.log has not been created: 
$version 
$changes "
} done
fi

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$download "
} done
fi

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Downloaded file size is to small: 
$url 
$size"
} done
fi

else
#file is already in database
echo $filename is  in database
echo
fi

else
#Last-Modified field no included
echo Last-Modified field no included
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not include Last-Modified: 
$url "
} done
echo 
echo
fi

else
#if http statis code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$url"
} done
echo 
echo
fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
