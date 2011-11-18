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
				httpdecode --decode "$url"
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

get_infopage () {
	cat "./$vid.info-page"
}

get_var () {
	grep "^$1=" | sed -e "s/^$1=//" | urldecode
}

get_varnames () {
	sed -e 's/&/\
/g' | sed -e 's/^\([^=]\+\)=.*$/\1/'
}

get_size () {
	sed -e 's/,/\
/g' | wc -l
}

get_index () {
	sed -e 's/,/\
/g' | head -n "$1" | tail -n 1 | sed -e 's/&/\
/g'
}

get_infopage_var () {
	get_infopage | get_var "$@"
}

readyn () {
	yn=i
	while test "$yn" != "y" \
	&&    test "$yn" != "Y" \
	&&    test "$yn" != "n" \
	&&    test "$yn" != "N"
	do
		echo "$@" >&2
		read yn
	done
	if test "$yn" = "y" || test "$yn" = "Y"
	then
		echo -n true
	else
		echo -n false
	fi
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
			-e 's_^\(http://\)\?\(www\.\)\?youtube\.com/watch?\(.*&\)\?v=\([-_0-9a-zA-Z]\+\)\(&.*$\)\?_\4_' \
			-e 's_^\(http://\)\?\(www\.\)\?youtube\.com/\(v\|embed\)/\([-_0-9a-zA-Z]\+\)\(&.*$\)\?_\4_' \
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
	info_page_url="http://www.youtube.com/get_video_info?&video_id=$vid&el=detailpage&ps=default&eurl=&gl=US&hl=en"
	
	for method in "youtube" "hidemyass.com"
	do
		case "$method" in
			youtube)
				wget -U Mozilla -nv "$info_page_url" -O -
				;;
			
			hidemyass.com)
				wget 'http://6.hidemyass.com/includes/process.php?action=update&idx=1' --post-data "obfuscation=1&u=$(httpencode "$info_page_url")" -O -
				;;
		esac | sed -e 's/&/\
/g' > "./$vid.info-page"
		if test "$(get_infopage_var status)" == "ok"
		then
			break
		fi
		echo -en "\e[31m" >&2
		get_infopage_var reason
		echo -en "\e[0m" >&2
		let pass=pass+1
	done
	if test "$(get_infopage_var status)" != "ok"
	then
		rm "./$vid.info-page"
		continue
	fi
	
	fmt_url_map="$(get_infopage_var fmt_url_map)"
	
	nb="$name_base"
	
	if test -z "$nb"
	then
		nb="$(get_infopage_var title | sed -e 's!/!_!g')"
	fi
	
	if test -n "$nb"
	then
		if test -n "$1" || test $part != 1
		then
			base="$nb (Split+Youtube: $part+$vid)"
			let part=part+1
		else
			base="$nb (Youtube: $vid)"
		fi
	else
		base="$vid"
	fi
	
	for i in $(seq 1 1 $(get_infopage | get_var url_encoded_fmt_stream_map | get_size))
	do
		url="$(get_infopage | get_var url_encoded_fmt_stream_map | get_index $i | get_var url)"
		itag="$(get_infopage | get_var url_encoded_fmt_stream_map | get_index $i | get_var itag)"
		name="$base.$itag.flv"
		
		ok=false
		
		if grep "^$itag$" ~/.bothie/dl-youtube.itag-whitelist >/dev/null 2>&1
		then
			echo -e "\e[32mUsing whitelisted itag $itag\e[0m"
			ok=true
		fi
		
		if ! $ok
		then
			ok=true
			if grep "^$itag$" ~/.bothie/dl-youtube.itag-blacklist >/dev/null 2>&1
			then
				echo -e "\e[31mSkipping blacklisted itag $itag\e[0m"
				ok=false
			fi
			if $ok
			then
				echo "itag=$itag is neither in ~/.bothie/dl-youtube.itag-whitelist nor in ~/.bothie/dl-youtube.itag-blacklist"
				accept=$(readyn "Do you want to accept this itag (y/n)?")
				if ! $accept
				then
					ok=false
				fi
				extendlist=$(readyn "Add this choice to $(
					$accept && echo -n "whitelist" || echo -n "blacklist"
				) (y/n)?")
				if $extendlist
				then
					if $accept
					then
						list="whitelist"
					else
						list="blacklist"
					fi
					if ! test -d ~/.bothie
					then
						mkdir ~/.bothie
					fi
					echo "$itag" >> ~/.bothie/dl-youtube.itag-$list
				fi
			fi
		fi
		
		if ! $ok
		then
			continue
		fi
		
		if test -z "$cont"
		then
			output="$name"
			let num=0
			while test -e "$output" \
			&& ( ! test -f "$output" \
			||     test -s "$output" )
			do
				let num=num+1
				output="$name.$num"
			done
			name="$output"
		fi
		
		t Downloading video to "$name"
		echo -n "Downloading actual video to " >&2
		echo "$name"
		
		case "$method" in
			youtube)
				wget $cont "$url" -O "$name" || exit 2
#				wget -U Mozilla -nv "$info_page_url" -O -
				;;
			
			hidemyass.com)
				wget $cont 'http://6.hidemyass.com/includes/process.php?action=update&idx=1' --post-data "obfuscation=1&u=$(httpencode "$url")" -O "$name" || exit 2
#				wget 'http://6.hidemyass.com/includes/process.php?action=update&idx=1' --post-data "obfuscation=1&u=$(httpencode "$info_page_url")" -O -
				;;
		esac
		
#		for name in $(get_infopage | get_var url_encoded_fmt_stream_map | get_index $i | get_varnames)
#		do
#			echo -en "\t$name: "
#			get_infopage | get_var url_encoded_fmt_stream_map | get_index $i | get_var $name
#		done
		
		break
	done
	
	test -s "$name" && rm "./$vid.info-page"
done
t ""
