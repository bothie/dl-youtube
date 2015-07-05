#! /bin/sh

if test "$#" -gt 0
then
	for i in "$@"
	do
		echo "$1" | "$0"
	done
	exit 0
fi

if test -n "$(type -p httpdecode)"
then
	(
		while read url
		do
			httpdecode --decode "$url"
			echo
		done
	)
else
	sed \
		-e 's/+/ /g' \
		-e 's/%22/"/g' \
		-e "s/%23/#/g" \
		-e 's_%26_\&_g' \
		-e "s/%27/'/g" \
		-e "s/%28/(/g" \
		-e "s/%29/)/g" \
		-e 's_%2C_,_g' \
		-e 's_%2F_/_g' \
		-e 's/%3A/:/g' \
		-e 's/%3D/=/g' \
		-e 's/%3F/?/g' \
		-e 's/%5B/[/g' \
		-e 's/%5D/]/g' \
		-e 's/%25/%/g' \
		-e 's/%C3%BC/ü/g' \
		-e 's/%C3%B6/ö/g' \
		-e 's/%C3%96/Ö/g' \

fi
