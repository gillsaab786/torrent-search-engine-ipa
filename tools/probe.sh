#!/usr/bin/env bash
# Fetches each candidate source once and saves the raw response, so parsers
# can be written against what the sites really return.
set -u
OUT=${1:-probe}
mkdir -p "$OUT"
UA='Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
SUM="$OUT/SUMMARY.txt"
: > "$SUM"

probe() { # name url
  local name=$1 url=$2
  local meta
  meta=$(curl -sS -L --compressed -m 25 -A "$UA" -H 'Accept-Language: en-US,en;q=0.9' \
    -o "$OUT/$name.body" -w '%{http_code} %{size_download} %{url_effective}' "$url" 2>&1)
  head -c 400000 "$OUT/$name.body" > "$OUT/$name.tmp" 2>/dev/null && mv "$OUT/$name.tmp" "$OUT/$name.body"
  local hits
  hits=$(grep -oiE 'magnet:\?xt=urn:btih:[a-z0-9]{32,40}|"info_?hash"|infohash|btih' "$OUT/$name.body" 2>/dev/null | wc -l | tr -d ' ')
  printf '%-22s %s hashes=%s\n' "$name" "$meta" "$hits" | tee -a "$SUM"
}

probe_post() { # name url json
  local name=$1 url=$2 body=$3
  local meta
  meta=$(curl -sS -L --compressed -m 25 -A "$UA" -H 'Content-Type: application/json' \
    -d "$body" -o "$OUT/$name.body" -w '%{http_code} %{size_download} %{url_effective}' "$url" 2>&1)
  local hits
  hits=$(grep -oiE '"hash"|magnet' "$OUT/$name.body" 2>/dev/null | wc -l | tr -d ' ')
  printf '%-22s %s hashes=%s\n' "$name" "$meta" "$hits" | tee -a "$SUM"
}

# --- general ---
probe_post knaben https://api.knaben.org/v1 '{"search_type":"100%","search_field":"title","query":"ubuntu","order_by":"seeders","order_direction":"desc","size":5,"hide_unsafe":true,"hide_xxx":true}'
probe apibay 'https://apibay.org/q.php?q=ubuntu'
probe torrentscsv 'https://torrents-csv.com/service/search?q=ubuntu&size=5'
probe torrentdownloads 'https://www.torrentdownloads.pro/rss.xml?type=search&search=ubuntu'
probe bitsearch_eu 'https://bitsearch.eu/search?q=ubuntu'
probe bitsearch_to 'https://bitsearch.to/search?q=ubuntu'
probe solidtorrents 'https://solidtorrents.to/search?q=ubuntu'
probe limetorrents_lol 'https://www.limetorrents.lol/search/all/ubuntu/seeds/1/'
probe limetorrents_fun 'https://www.limetorrents.fun/search/all/ubuntu/seeds/1/'
probe torrentproject 'https://torrentproject.com.se/browse?t=ubuntu'
probe magnetdl 'https://www.magnetdl.com/u/ubuntu/'
probe bt4g 'https://bt4gprx.com/search?q=ubuntu&page=rss'
probe glodls 'https://glodls.to/search_results.php?search=ubuntu'
probe rutor 'https://rutor.info/search/ubuntu'
probe rutor_is 'https://rutor.is/search/ubuntu'
probe x1337_to 'https://1337x.to/search/ubuntu/1/'
probe x1337_st 'https://1337x.st/search/ubuntu/1/'
probe x1337x_ws 'https://x1337x.ws/search/ubuntu/1/'
probe torlock 'https://www.torlock.com/all/torrents/ubuntu.html'
probe ext 'https://ext.to/search/?q=ubuntu'
probe therarbg 'https://therarbg.com/get-posts/keywords:ubuntu/'
probe therarbg_to 'https://therarbg.to/get-posts/keywords:ubuntu/'
probe archive 'https://archive.org/advancedsearch.php?q=ubuntu&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=btih&fl%5B%5D=item_size&fl%5B%5D=publicdate&rows=5&output=json'
probe btdig 'https://btdig.com/search?q=ubuntu'
probe torrentfunk 'https://www.torrentfunk.com/all/torrents/ubuntu.html'
probe torrends 'https://torrends.to/find/?q=ubuntu'
probe uindex 'https://uindex.org/search.php?search=ubuntu'
probe torrentdownload_info 'https://www.torrentdownload.info/search?q=ubuntu'
probe idope 'https://idope.se/torrent-list/ubuntu/'
probe academic 'https://academictorrents.com/browse.php?search=ubuntu'
probe linuxtracker 'https://linuxtracker.org/index.php?page=torrents&search=ubuntu'
probe torrentz2 'https://torrentz2.nz/search?q=ubuntu'
probe kickass 'https://kickasstorrents.to/usearch/ubuntu/'
probe tgx 'https://torrentgalaxy.one/get-posts/keywords:ubuntu/'
# --- movies / TV ---
probe yts_mx 'https://yts.mx/api/v2/list_movies.json?query_term=inception&limit=2'
probe yts_bz 'https://yts.bz/api/v2/list_movies.json?query_term=inception&limit=2'
probe yts_gg 'https://yts.gg/api/v2/list_movies.json?query_term=inception&limit=2'
probe yts_lt 'https://yts.lt/api/v2/list_movies.json?query_term=inception&limit=2'
probe eztv_search 'https://eztvx.to/search/the-office'
probe eztv_api 'https://eztvx.to/api/get-torrents?imdb_id=0386676&limit=5'
# --- anime ---
probe nyaa 'https://nyaa.si/?page=rss&q=one+piece'
probe animetosho 'https://feed.animetosho.org/json?q=one%20piece'
probe tokyotosho 'https://www.tokyotosho.info/rss.php?terms=one+piece'
probe subsplease 'https://subsplease.org/api/?f=search&tz=UTC&s=one%20piece'
probe anidex 'https://anidex.info/rss/?q=one+piece'
