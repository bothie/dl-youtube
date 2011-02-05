#! /bin/sh

t () {
	settitle "[${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}]$ $*"
}

processed_arg=true

name_base=""
part=1
cont=""

while $processed_arg
do
	processed_arg=false
	if test "X-O" = "X$1"
	then
		processed_arg=true
		shift
		name_base="$1"
		shift
	fi
	if test "X--part" == "X$1"
	then
		processed_arg=true
		shift
		part="$1"
		shift
	fi
	if test "X-c" = "X$1"
	then
		processed_arg=true
		cont="-c"
		shift
	fi
done

if test -z "$1"
then
	echo "Syntax: $0 [-c] [-O <target-filename-base>] <youtube-url> [...]" >&2
	exit 1
fi

urldecode () {
	if test -n "$(type -p httpdecode)"
	then
		(
			while read url
			do
				httpdecode "$url"
			done
		)
	else
		sed \
			-e 's/+/ /g' \
			-e 's_%26_\&_g' \
			-e 's_%2F_/_g' \
			-e 's/%3A/:/g' \
			-e 's/%3D/=/g' \
			-e 's/%3F/?/g' \
			-e 's/%25/%/g' \
	
	fi
}

get_var () {
	grep "^$1=" "./$vid.info-page" | sed -e "s/^$1=//"
}

while test -n "$1"
do
	if test "X-O" = "X$1"
	then
		shift
		name_base="$1"
		shift
		continue
	fi
	
	vid="$(
		echo "$1" | sed \
			-e 's_^\(http://\)\?\(www\.\)\?youtube\.com/watch?v=\([-_0-9a-zA-Z]\+\)\(&.*$\)\?_\3_' \
			-e 's_^\(http://\)\?\(www\.\)\?youtube\.com/v/\([-_0-9a-zA-Z]\+\)\(&.*$\)\?_\3_' \
		
	)"
	shift
	
	t got vid "$vid"
	if test "$(echo -n "$vid" | wc -c)" != 11
	then
		echo "Couldn't parse the argument (got $vid). Please try to just give the video id (the 11 digits and letters)"
		exit 2
	fi
	
	t dl infopage "$vid"
	echo "Downloading Info page for video (vid=$vid) ..." >&2
	wget -U Mozilla -nv "http://www.youtube.com/get_video_info?&video_id=$vid&el=detailpage&ps=default&eurl=&gl=US&hl=en" -O - | sed -e 's/&/\
/g' > "./$vid.info-page"
	
	if test "$(get_var status)" != "ok"
	then
		echo -en "\e[31m" >&2
		httpdecode "$(get_var reason)"
		echo -en "\e[0m" >&2
		rm "./$vid.info-page"
		continue
	fi
	
	fmt_url_map="$(get_var fmt_url_map)"
	
	nb="$name_base"
	
	if test -z "$nb"
	then
		nb="$(get_var title | urldecode | sed -e 's!/!_!g')"
	fi
	
	if test -n "$nb"
	then
		if test -n "$1" || test $part != 1
		then
			name="$nb (Split+Youtube: $part+$vid)"
			let part=part+1
		else
			name="$nb (Youtube: $vid)"
		fi
	else
		name="$vid"
	fi
	name="$name.flv"
	
	if test -z "$cont"
	then
		output="$name"
		let num=0
		while test -e "$output"
		do
			let num=num+1
			output="$name.$num"
		done
		name="$output"
	fi
	
	t Downloading video to "$name"
	echo -n "Downloading actual video to " >&2
	echo "$name"
	
	echo "fmt_url_map:"
	echo "$fmt_url_map" | sed -e 's/%2C/\
/g' | sed -e 's/%7C/ /'
	
	wget $cont "$(
		get_var fmt_url_map | sed -e 's/%2C/\
/g' | sed -e 's/%7C/ /' | grep -v "^\(37\|22\) " | head -n 1 | while read fmt url
		do
			echo "$url" | urldecode
		done
	)" -O "$name" || exit 2
	
	rm "./$vid.info-page"
done
t ""
