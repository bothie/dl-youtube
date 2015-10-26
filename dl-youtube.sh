#! /bin/sh
#
# Change-Credits:
# 2012-10-01: petya: http://www.ngcoders.com/php-script/php-youtube-video-downloader-script/#comment-16211
# 	* USER_AGENT statt nur "Mozilla" auf "Mozilla/5.0 usw" gesetzt
# 	* sig-Variable an video url anhängen - also url="$url&signature=$sig"

set -o pipefail

WGET=/usr/bin/wget
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.89 Safari/537.1"

hidemyass_domain=1.hidemyass.com

. unicode_unification

t () {
	settitle "[$video_num/$num_args] $*"
#	settitle "[${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}]$ [$video_num/$num_args] $*"
	$nv || echo "$*"
}

processed_arg=true

name_base=""
part=1
cont=""
from_playlist=false
blacklist=""
whitelist=""
nv=false
nv_arg=""
nvq_arg="-nv"

declare -a wget_extra_arguments
declare -a dl_youtune_extra_arguments

while $processed_arg
do
	processed_arg=false
	case "$1" in
		"-O")
			processed_arg=true
			shift
			name_base="$1"
			shift
			continue
			;;

		"--part")
			processed_arg=true
			shift
			part="$1"
			shift
			continue
			;;

		"-c")
			processed_arg=true
			cont="-c"
			dl_youtune_extra_arguments+=("$1")
			shift
			continue
			;;
		
		"--from-playlist")
			processed_arg=true
			from_playlist=true
			shift
			continue
			;;
		
		"--wget")
			processed_arg=true
			shift
			echo "Found wget argument $1"
			wget_extra_arguments+=("$1")
			dl_youtune_extra_arguments+=("--wget")
			dl_youtune_extra_arguments+=("$1")
			shift
			continue
			;;
		
		"-nv")
			processed_arg=true
			shift
			wget_extra_arguments+=("-nv")
			dl_youtune_extra_arguments+=("-nv")
			nv=true
			nv_arg="-nv"
			nvq_arg="-q"
			continue
			;;
		
		"--blacklist")
			processed_arg=true
			shift
			blacklist="$1"
			dl_youtune_extra_arguments+=("--blacklist")
			dl_youtune_extra_arguments+=("$1")
			shift
			continue
			;;
		
		"--whitelist")
			processed_arg=true
			shift
			whitelist="$1"
			dl_youtune_extra_arguments+=("--whitelist")
			dl_youtune_extra_arguments+=("$1")
			shift
			continue
			;;
	esac
done

if test -z "$1"
then
	echo "Syntax: $0 [-c] [-O <target-filename-base>] <youtube-url> [...]" >&2
	exit 1
fi

num_args=$#
num_digits=1
video_num=0
if test $num_args -gt    10; then num_digits=2; fi
if test $num_args -gt   100; then num_digits=3; fi
if test $num_args -gt  1000; then num_digits=4; fi
if test $num_args -gt 10000; then num_digits=5; fi

urlencode () {
	$nv || echo ">>> urlencode" >&2
	if test -n "$(type -p httpencode)"
	then
		(
			while read url
			do
				httpencode --encode "$url"
			done
		)
	else
		for url in "$@"
		do
			result="$(
				echo "$url" \
				| sed \
					-e 's/+/%2B/g' \
					-e 's/ /+/g' \
					-e 's/&/%26/g' \
					-e 's/=/%3D/g' \
			
			)"
			$nv || echo "»$url« -> »$result«" >&2
			echo "$result"
		done
	fi
	$nv || echo "<<< urlencode" >&2
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
	
	plid="$(
		# grep "/playlist?" | 
		
		echo "$1" | sed \
			-e 's_^\(https\?://\)\?\(www\.\)\?youtube\(-nocookie\)\?\.com/playlist?list=\(\(PL\|SP\)[-0-9A-Za-z]\+\)\(&.*$\)\?$_\4_'  \
	)"
	$nv || echo "plid=»$plid«"
	if test "$(echo -n "$plid" | wc -c)" == 18 \
	|| test "$(echo -n "$plid" | wc -c)" == 34
	then
		shift
		
		t got playlist id "$plid"
		$WGET $nv_arg "http://www.youtube.com/playlist?list=$plid" -O "$plid.play-list.html" || continue
		if test -n "$name_base"
		then
			title="$name_base"
		else
			title="$(
				grep 'title" content="[^"]*"' "$plid.play-list.html" | sed -e 's/^.*title" content="\([^"]*\)".*$/\1/'
			)"
		fi
		dir="$title (Youtube: $plid)"
		$nv || echo "Downloading playlist into $dir"
		test -d "$dir" || mkdir "$dir" || continue
		(
			cd "$dir"
			dl-youtube "${dl_youtune_extra_arguments[@]}" --from-playlist $(
				regex1="^.*a href=\"/watch?v=\(...........\)&amp;list=$plid&amp;index=[0-9]\+.*"
				regex2="^.*a href=\"/watch?v=\(...........\)&amp;index=[0-9]\+&amp;list=$plid\".*"
				grep "$regex1\|$regex2" "../$plid.play-list.html" \
				| sed \
					-e "s!$regex1!\1!" \
					-e "s!$regex2!\1!" \
				
			)
		)
		continue
	fi
	
	vid="$(
		echo "$1" | sed \
			-e 's_^\(https\?://\)\?\(www\.\)\?youtu\(be\(-nocookie\)\?\.com\|\.be\)/watch?\(.*&\)\?v=\([-_0-9a-zA-Z]\+\)\([#&].*$\)\?_\6_' \
			-e 's_^\(https\?://\)\?\(www\.\)\?youtu\(be\(-nocookie\)\?\.com\|\.be\)/\(\(v\|embed\)/\)\?\([-_0-9a-zA-Z]\+\)\([#&].*$\)\?_\7_' \
	)"
	shift
	
	t got vid "$vid"
	if test "$(echo -n "$vid" | wc -c)" != 11
	then
		echo "Couldn't parse the argument ($1 -> $vid). Please try to just give the video id (the 11 digits and letters)" >&2
		continue
	fi
	
	t dl infopage "$vid"
	$nv || echo "Downloading Info page for video (vid=$vid) ..." >&2
	info_page_url_detailpage="http://www.youtube.com/get_video_info?video_id=$vid&el=detailpage&ps=default&eurl=&gl=US&hl=en"
	info_page_url_embedded="http://www.youtube.com/get_video_info?el=embedded&video_id=$vid"
	
	for method in \
		"youtube-embedded" \
		"hidemyass.com-embedded" \
		"youtube-detailpage" \
		"hidemyass.com-detailpage" \
	; do
		case "$method" in
			youtube-detailpage)
				$WGET $nvq_arg -U "$USER_AGENT" "$info_page_url_detailpage" -O -
				;;
			
			hidemyass.com-detailpage)
				$WGET $nvq_arg "http://$hidemyass_domain/includes/process.php?action=update&idx=1" --post-data "obfuscation=1&u=$(urlencode "$info_page_url_detailpage")" -O -
				;;
			
			youtube-embedded)
				$WGET $nvq_arg -U "$USER_AGENT" "$info_page_url_embedded" -O -
				;;
			
			hidemyass.com-embedded)
				$WGET $nvq_arg "http://$hidemyass_domain/includes/process.php?action=update&idx=1" --post-data "obfuscation=1&u=$(urlencode "$info_page_url_embedded")" -O -
				;;
		esac | sed -e 's/&/\
/g' > "./$vid.info-page"
		if test "$(get_infopage_var status)" == "ok"
		then
			break
		fi
		echo -en "\e[31mTried to download %vid using method $method: " >&2
		get_infopage_var reason
		echo -en "\e[0m" >&2
		let pass=pass+1
	done
	
	base="$name_base"
	
	if test -z "$base"
	then
		if test "$(get_infopage_var status)" != "ok"
		then
			base="fail"
		else
			base="$(get_infopage_var title | sed -e 's!/!_!g' | unicode_unification)"
		fi
	fi
	
	if test -z "$base"
	then
		base="$vid"
		split_youtube=""
	fi
	
	if $from_playlist
	then
		base="$(printf "[%0*i] %s" $num_digits $video_num "$base")"
		let video_num=video_num+1
	fi
	
	if test -n "$name_base" || test $part != 1
	then
		split_youtube=" (Split+Youtube: $part+$vid)"
		let part=part+1
	else
		split_youtube=" (Youtube: $vid)"
	fi
	
	if test "$(get_infopage_var status)" != "ok"
	then
		rm "./$vid.info-page"
		continue
	fi
	
	size="$(get_infopage_var url_encoded_fmt_stream_map | get_size)"
	$nv || echo "Infopage url map size: $size"
	for i in $(seq 1 1 $size)
	do
		index="$(get_infopage_var url_encoded_fmt_stream_map | get_index $i)"
		$nv || echo "$index" | urldecode
#		foreach($urls as $url)
#		{
#		$uc=explode(“&”,$url);
#		$um=explode(“=”,$uc[1]);
#		$ul=explode(“=”,$uc[0]);
#		$si=explode(“=”,$uc[4]);
#		$u = urldecode($um[1]);
#		$foundArray[$ul[1]] = $u.”&signature=”.$si[1];
#		}
		
		url="$(echo "$index" | get_var url)"
		itag="$(echo "$index" | get_var itag)"
		sig="$(echo "$index" | get_var sig)"
		test -n "$sig" && url="$url&signature=$sig"
		
		ok=false
		
		if echo "$whitelist" | grep "^$itag$" >/dev/null 2>&1
		then
			$nv || echo -e "\e[32mUsing whitelisted itag $itag\e[0m"
			ok=true
		else
			if echo "$blacklist" | grep "^$itag$" >/dev/null 2>&1
			then
				$nv || echo -e "\e[31mSkipping blacklisted itag $itag\e[0m"
				continue
			fi
		fi
		
		if ! $ok && grep "^$itag$" ~/.bothie/dl-youtube.itag-whitelist >/dev/null 2>&1
		then
			$nv || echo -e "\e[32mUsing whitelisted itag $itag\e[0m"
			ok=true
		fi
		
		if ! $ok
		then
			ok=true
			if grep "^$itag$" ~/.bothie/dl-youtube.itag-blacklist >/dev/null 2>&1
			then
				$nv || echo -e "\e[31mSkipping blacklisted itag $itag\e[0m"
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
				if $accept
				then
					list="whitelist"
				else
					list="blacklist"
				fi
				extendlist=$(readyn "Add this choice to $list (y/n)?")
				if $extendlist
				then
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
		
		while true
		do
			output="$base$split_youtube.$itag.flv"
			if test -z "$cont"
			then
				let collision_protect_num=0
				while test -e "$output" \
				&& ( ! test -f "$output" \
				||     test -s "$output" )
				do
					let collision_protect_num=collision_protect_num+1
					output="$base$split_youtube.$itag.flv.$collision_protect_num"
				done
			fi
			touch -- "$output" && break
			base="$( printf "%.$(( $(echo -n "$base" | wc -c) - 1 ))s" "$base" )"
			if test -z "$base"
			then
				base="$vid"
				split_youtube=""
			fi
		done
		name="$output"
		
		t Downloading video to "$name"
		if ! $nv
		then
			echo -n "Downloading actual video to " >&2
			echo "$name"
		fi
		
		sleep 1
		
		case "$method" in
			"youtube-embedded"|"youtube-detailpage")
				if $nv
				then
					(
						$WGET "${wget_extra_arguments[@]}" $cont "$url" -O "$name" 2>&1 \
						| sed -e "s/^\([-0-9: ]\+\) URL:[^ ]* \(\[[0-9/]\+\] -> \".*\" \[[0-9]\+\]\)$/\1 YT:$vid \2/"
					) || exit 2
				else
					$WGET "${wget_extra_arguments[@]}" $cont "$url" -O "$name" || exit 2
				fi
				;;
			
			"hidemyass.com-embedded"|"hidemyass.com-detailpage")
				$WGET "${wget_extra_arguments[@]}" $cont "http://$hidemyass_domain/includes/process.php?action=update&idx=1" --post-data "obfuscation=1&u=$(urlencode "$url")" -O "$name" || exit 2
				;;
		esac
		
#		for name in $(echo "$index" | get_varnames)
#		do
#			echo -en "\t$name: "
#			echo "$index" | get_var $name
#		done
		
		break
	done
	
	test -s "$name" && rm "./$vid.info-page"
done
t ""
