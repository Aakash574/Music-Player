/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:convert';

import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:blackhole/APIs/spotify_api.dart';
import 'package:blackhole/Helpers/matcher.dart';
import 'package:blackhole/Helpers/spotify_helper.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

// ignore: avoid_classes_with_only_static_members
class Lyrics {
  static Future<Map<String, String>> getLyrics({
    required String id,
    required String title,
    required String artist,
    required bool saavnHas,
  }) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': '',
      'id': id,
    };

    Logger.root.info('Getting Synced Lyrics');
    final res = await getSpotifyLyrics(title, artist);
    result['lyrics'] = res['lyrics']!;
    result['type'] = res['type']!;
    result['source'] = res['source']!;
    if (result['lyrics'] == '') {
      Logger.root.info('Synced Lyrics, not found. Getting text lyrics');
      if (saavnHas) {
        Logger.root.info('Getting Lyrics from Saavn');
        result['lyrics'] = await getSaavnLyrics(id);
        result['type'] = 'text';
        result['source'] = 'Jiosaavn';
        if (result['lyrics'] == '') {
          final res = await getLyrics(
            id: id,
            title: title,
            artist: artist,
            saavnHas: false,
          );
          result['lyrics'] = res['lyrics']!;
          result['type'] = res['type']!;
          result['source'] = res['source']!;
        }
      } else {
        Logger.root
            .info('Lyrics not available on Saavn, finding on Musixmatch');
        result['lyrics'] =
            await getMusixMatchLyrics(title: title, artist: artist);
        result['type'] = 'text';
        result['source'] = 'Musixmatch';
        if (result['lyrics'] == '') {
          Logger.root
              .info('Lyrics not found on Musixmatch, searching on Google');
          result['lyrics'] =
              await getGoogleLyrics(title: title, artist: artist);
          result['type'] = 'text';
          result['source'] = 'Google';
        }
      }
    }
    return result;
  }

  static Future<String> getSaavnLyrics(String id) async {
    try {
      final Uri lyricsUrl = Uri.https(
        'www.jiosaavn.com',
        '/api.php?__call=lyrics.getLyrics&lyrics_id=$id&ctx=web6dot0&api_version=4&_format=json',
      );
      final Response res =
          await get(lyricsUrl, headers: {'Accept': 'application/json'});

      final List<String> rawLyrics = res.body.split('-->');
      Map fetchedLyrics = {};
      if (rawLyrics.length > 1) {
        fetchedLyrics = json.decode(rawLyrics[1]) as Map;
      } else {
        fetchedLyrics = json.decode(rawLyrics[0]) as Map;
      }
      final String lyrics =
          fetchedLyrics['lyrics'].toString().replaceAll('<br>', '\n');
      return lyrics;
    } catch (e) {
      Logger.root.severe('Error in getSaavnLyrics', e);
      return '';
    }
  }

  static Future<Map<String, String>> getSpotifyLyrics(
    String title,
    String artist,
  ) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    await callSpotifyFunction(
      function: (String accessToken) async {
        final value = await SpotifyApi().searchTrack(
          accessToken: accessToken,
          query: '$title - $artist',
          limit: 1,
        );
        try {
          // Logger.root.info(jsonEncode(value['tracks']['items'][0]));
          if (value['tracks']['items'].length == 0) {
            Logger.root.info('No song found');
            return result;
          }
          String title2 = '';
          String artist2 = '';
          try {
            title2 = value['tracks']['items'][0]['name'].toString();
            artist2 =
                value['tracks']['items'][0]['artists'][0]['name'].toString();
          } catch (e) {
            Logger.root.severe(
              'Error in extracting artist/title in getSpotifyLyrics for $title - $artist',
              e,
            );
          }
          final trackId = value['tracks']['items'][0]['id'].toString();
          if (matchSongs(
            title: title,
            artist: artist,
            title2: title2,
            artist2: artist2,
          )) {
            final Map<String, String> res =
                await getSpotifyLyricsFromId(trackId);
            result['lyrics'] = res['lyrics']!;
            result['type'] = res['type']!;
            result['source'] = res['source']!;
          } else {
            Logger.root.info('Song not matched');
          }
        } catch (e) {
          Logger.root.severe('Error in getSpotifyLyrics', e);
        }
      },
      forceSign: false,
    );
    return result;
  }

  static Future<Map<String, String>> getSpotifyLyricsFromId(
    String trackId,
  ) async {
    final Map<String, String> result = {
      'lyrics': '',
      'type': 'text',
      'source': 'Spotify',
    };
    try {
      final Uri lyricsUrl = Uri.https('spotify-lyric-api.herokuapp.com', '/', {
        'trackid': trackId,
        'format': 'lrc',
      });
      final Response res =
          await get(lyricsUrl, headers: {'Accept': 'application/json'});

      if (res.statusCode == 200) {
        final Map lyricsData = await json.decode(res.body) as Map;
        if (lyricsData['error'] == false) {
          final List lines = await lyricsData['lines'] as List;
          if (lyricsData['syncType'] == 'LINE_SYNCED') {
            result['lyrics'] = lines
                .map((e) => '[${e["timeTag"]}]${e["words"]}')
                .toList()
                .join('\n');
            result['type'] = 'lrc';
          } else {
            result['lyrics'] = lines.map((e) => e['words']).toList().join('\n');
            result['type'] = 'text';
          }
        }
      } else {
        Logger.root.severe(
          'getSpotifyLyricsFromId returned ${res.statusCode}',
          res.body,
        );
      }
      return result;
    } catch (e) {
      Logger.root.severe('Error in getSpotifyLyrics', e);
      return result;
    }
  }

  static Future<String> getGoogleLyrics({
    required String title,
    required String artist,
  }) async {
    const String url =
        'https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=';
    const String delimiter1 =
        '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const String delimiter2 =
        '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';
    String lyrics = '';
    try {
      lyrics = (await get(
        Uri.parse(Uri.encodeFull('$url$title by $artist lyrics')),
      ))
          .body;
      lyrics = lyrics.split(delimiter1).last;
      lyrics = lyrics.split(delimiter2).first;
      if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
    } catch (_) {
      try {
        lyrics = (await get(
          Uri.parse(
            Uri.encodeFull('$url$title by $artist song lyrics'),
          ),
        ))
            .body;
        lyrics = lyrics.split(delimiter1).last;
        lyrics = lyrics.split(delimiter2).first;
        if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
      } catch (_) {
        try {
          lyrics = (await get(
            Uri.parse(
              Uri.encodeFull(
                '$url${title.split("-").first} by $artist lyrics',
              ),
            ),
          ))
              .body;
          lyrics = lyrics.split(delimiter1).last;
          lyrics = lyrics.split(delimiter2).first;
          if (lyrics.contains('<meta charset="UTF-8">')) throw Error();
        } catch (_) {
          lyrics = '';
        }
      }
    }
    return lyrics.trim();
  }

  static Future<String> getOffLyrics(String path) async {
    try {
      final Audiotagger tagger = Audiotagger();
      final Tag? tags = await tagger.readTags(path: path);
      return tags?.lyrics ?? '';
    } catch (e) {
      return '';
    }
  }

  static Future<String> getLyricsLink(String song, String artist) async {
    const String authority = 'www.musixmatch.com';
    final String unencodedPath = '/search/$song $artist';
    final Response res = await get(Uri.https(authority, unencodedPath));
    if (res.statusCode != 200) return '';
    final RegExpMatch? result =
        RegExp(r'href=\"(\/lyrics\/.*?)\"').firstMatch(res.body);
    return result == null ? '' : result[1]!;
  }

  static Future<String> scrapLink(String unencodedPath) async {
    Logger.root.info('Trying to scrap lyrics from $unencodedPath');
    const String authority = 'www.musixmatch.com';
    final Response res = await get(Uri.https(authority, unencodedPath));
    if (res.statusCode != 200) return '';
    final List<String?> lyrics = RegExp(
      r'<span class=\"lyrics__content__ok\">(.*?)<\/span>',
      dotAll: true,
    ).allMatches(res.body).map((m) => m[1]).toList();

    return lyrics.isEmpty ? '' : lyrics.join('\n');
  }

  static Future<String> getMusixMatchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final String link = await getLyricsLink(title, artist);
      Logger.root.info('Found Musixmatch Lyrics Link: $link');
      final String lyrics = await scrapLink(link);
      return lyrics;
    } catch (e) {
      Logger.root.severe('Error in getMusixMatchLyrics', e);
      return '';
    }
  }
}
