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

import 'package:blackhole/Helpers/extensions.dart';
import 'package:blackhole/Models/song_item.dart';
import 'package:blackhole/Services/ytmusic/nav.dart';
import 'package:blackhole/Services/ytmusic/playlist.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

class YtMusicService {
  static const ytmDomain = 'music.youtube.com';
  static const httpsYtmDomain = 'https://music.youtube.com';
  static const baseApiEndpoint = '/youtubei/v1/';
  static const ytmParams = {
    'alt': 'json',
    'key': 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30',
  };
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0';
  static const Map<String, String> endpoints = {
    'search': 'search',
    'browse': 'browse',
    'get_song': 'player',
    'get_playlist': 'playlist',
    'get_album': 'album',
    'get_artist': 'artist',
    'get_video': 'video',
    'get_channel': 'channel',
    'get_lyrics': 'lyrics',
    'search_suggestions': 'music/get_search_suggestions',
    'next': 'next',
  };
  static const filters = [
    'albums',
    'artists',
    'playlists',
    'community_playlists',
    'featured_playlists',
    'songs',
    'videos',
  ];
  static const scopes = ['library', 'uploads'];

  Map<String, String>? headers;
  int? signatureTimestamp;
  Map<String, dynamic>? context;

  static final YtMusicService _singleton = YtMusicService._internal();

  factory YtMusicService() {
    return _singleton;
  }

  YtMusicService._internal();

  Map<String, String> initializeHeaders() {
    return {
      'user-agent': userAgent,
      'accept': '*/*',
      'accept-encoding': 'gzip, deflate',
      'content-type': 'application/json',
      'content-encoding': 'gzip',
      'origin': httpsYtmDomain,
      'cookie': 'CONSENT=YES+1',
    };
  }

  Future<Response> sendGetRequest(
    String url,
    Map<String, String>? headers,
  ) async {
    final Uri uri = Uri.https(url);
    final Response response = await get(uri, headers: headers);
    return response;
  }

  Future<String?> getVisitorId(Map<String, String>? headers) async {
    final response = await sendGetRequest(ytmDomain, headers);
    final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
    final matches = reg.firstMatch(response.body);
    String? visitorId;
    if (matches != null) {
      final ytcfg = json.decode(matches.group(1).toString());
      visitorId = ytcfg['VISITOR_DATA']?.toString();
    }
    return visitorId;
  }

  Map<String, dynamic> initializeContext() {
    final DateTime now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');
    final String day = now.day.toString().padLeft(2, '0');
    final String date = year + month + day;
    return {
      'context': {
        'client': {'clientName': 'WEB_REMIX', 'clientVersion': '1.$date.01.00'},
        'user': {},
      },
    };
  }

  Future<Map> sendRequest(
    String endpoint,
    Map body,
    Map<String, String>? headers,
  ) async {
    final Uri uri = Uri.https(ytmDomain, baseApiEndpoint + endpoint, ytmParams);
    final response = await post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map;
    } else {
      Logger.root
          .severe('YtMusic returned ${response.statusCode}', response.body);
      Logger.root.info('Requested endpoint: $uri');
      return {};
    }
  }

  String? getParam2(String filter) {
    final filterParams = {
      'songs': 'I',
      'videos': 'Q',
      'albums': 'Y',
      'artists': 'g',
      'playlists': 'o',
    };
    return filterParams[filter];
  }

  String? getSearchParams({
    String? filter,
    String? scope,
    bool ignoreSpelling = false,
  }) {
    String? params;
    String? param1;
    String? param2;
    String? param3;
    if (!ignoreSpelling && filter == null && scope == null) {
      return params;
    }

    if (scope == 'uploads') {
      params = 'agIYAw%3D%3D';
    }

    if (scope == 'library') {
      if (filter != null) {
        param1 = 'EgWKAQI';
        param2 = getParam2(filter);
        param3 = 'AWoKEAUQCRADEAoYBA%3D%3D';
      } else {
        params = 'agIYBA%3D%3D';
      }
    }

    if (scope == null && filter != null) {
      if (filter == 'playlists') {
        params = 'Eg-KAQwIABAAGAAgACgB';
        if (!ignoreSpelling) {
          params += 'MABqChAEEAMQCRAFEAo%3D';
        } else {
          params += 'MABCAggBagoQBBADEAkQBRAK';
        }
      } else {
        if (filter.contains('playlists')) {
          param1 = 'EgeKAQQoA';
          if (filter == 'featured_playlists') {
            param2 = 'Dg';
          } else {
            // community_playlists
            param2 = 'EA';
          }

          if (!ignoreSpelling) {
            param3 = 'BagwQDhAKEAMQBBAJEAU%3D';
          } else {
            param3 = 'BQgIIAWoMEA4QChADEAQQCRAF';
          }
        } else {
          param1 = 'EgWKAQI';
          param2 = getParam2(filter);
          if (!ignoreSpelling) {
            param3 = 'AWoMEA4QChADEAQQCRAF';
          } else {
            param3 = 'AUICCAFqDBAOEAoQAxAEEAkQBQ%3D%3D';
          }
        }
      }
    }

    if (scope == null && filter == null && ignoreSpelling) {
      params = 'EhGKAQ4IARABGAEgASgAOAFAAUICCAE%3D';
    }

    if (params != null) {
      return params;
    } else {
      if (param1 == null && param2 == null && param3 == null) {
        return null;
      }
      return '${param1 ?? ""}${param2 ?? ""}${param3 ?? ""}';
    }
  }

  Future<void> init() async {
    headers = initializeHeaders();
    if (!headers!.containsKey('X-Goog-Visitor-Id')) {
      headers!['X-Goog-Visitor-Id'] = await getVisitorId(headers) ?? '';
    }
    context = initializeContext();
    context!['context']['client']['hl'] = 'en';
  }

  Future<List<Map>> search(
    String query, {
    String? scope,
    bool ignoreSpelling = false,
    String? filter,
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['query'] = query;
      final params = getSearchParams(
        filter: filter,
        scope: scope,
        ignoreSpelling: ignoreSpelling,
      );
      if (params != null) {
        body['params'] = params;
      }
      final List<Map> searchResults = [];
      final res = await sendRequest(endpoints['search']!, body, headers);
      if (!res.containsKey('contents')) {
        Logger.root.info('YtMusic returned no contents');
        return List.empty();
      }

      Map<String, dynamic> results = {};

      if ((res['contents'] as Map).containsKey('tabbedSearchResultsRenderer')) {
        final tabIndex =
            (scope == null || filter != null) ? 0 : scopes.indexOf(scope) + 1;
        results = NavClass.nav(res, [
          'contents',
          'tabbedSearchResultsRenderer',
          'tabs',
          tabIndex,
          'tabRenderer',
          'content',
        ]) as Map<String, dynamic>;
      } else {
        Logger.root.info('tabbedSearchResultsRenderer not found');
        results = res['contents'] as Map<String, dynamic>;
      }

      final List finalResults =
          NavClass.nav(results, ['sectionListRenderer', 'contents']) as List? ??
              [];
      for (final sectionItem in finalResults) {
        final bool containsHeader =
            (sectionItem as Map).containsKey('musicCardShelfRenderer');
        final sectionSearchResults = [];
        final String sectionSelfRenderer =
            containsHeader ? 'musicCardShelfRenderer' : 'musicShelfRenderer';

        final String sectionTitle = NavClass.joinRunTexts(
          NavClass.nav(sectionItem, [
            sectionSelfRenderer,
            ...NavClass.titleRuns,
          ]) as List?,
        );

        final String sectionHeader = NavClass.joinRunTexts(
          NavClass.nav(sectionItem, [
            sectionSelfRenderer,
            ...NavClass.headerCardShelf,
            ...NavClass.titleRuns,
          ]) as List?,
        );

        if (containsHeader) {
          Logger.root.info('This search contains header');
          final res = parseInfoFromSubtitle(
            sectionItem,
            titleNavPath: [sectionSelfRenderer, ...NavClass.titleRuns],
            subtitleNavPath: [sectionSelfRenderer, ...NavClass.subtitleRuns],
            imageNavPath: [sectionSelfRenderer, ...NavClass.thumbnails],
            idNavPath: [
              sectionSelfRenderer,
              ...NavClass.titleRun,
              ...NavClass.navigationVideoId,
            ],
            idNavPath2: [
              sectionSelfRenderer,
              ...NavClass.titleRun,
              ...NavClass.navigationBrowseId,
            ],
          );
          if (res != null) sectionSearchResults.add(res);
        }

        final List sectionChildItems =
            NavClass.nav(sectionItem, [sectionSelfRenderer, 'contents'])
                    as List? ??
                [];

        for (final childItem in sectionChildItems) {
          final res = parseInfoFromSubtitle(childItem as Map);
          if (res != null) sectionSearchResults.add(res);
        }
        if (sectionSearchResults.isNotEmpty) {
          searchResults.add({
            'title': sectionHeader != '' ? sectionHeader : sectionTitle,
            'items': sectionSearchResults,
          });
        }
      }
      return searchResults;
    } catch (e) {
      Logger.root.severe('Error in yt search', e);
      return List.empty();
    }
  }

  Future<List<SongItem>> searchSongs(
    String query, {
    bool ignoreSpelling = false,
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final searchResults = await search(
        query,
        ignoreSpelling: ignoreSpelling,
        filter: 'songs',
      );
      final List<SongItem> songs = [];
      for (final section in searchResults) {
        if (section['title'] != 'Songs') {
          continue;
        }
        for (final item in section['items'] as List) {
          item['permaUrl'] = 'https://youtube.com/watch?v=${item["id"]}';
          final songItem = SongItem.fromMap(item as Map);
          songs.add(songItem);
        }
      }
      return songs;
    } catch (e) {
      Logger.root.severe('Error in yt song search', e);
      return List.empty();
    }
  }

  Future<List<String>> getSearchSuggestions({
    required String query,
    String? scope,
    bool ignoreSpelling = false,
    String? filter = 'songs',
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['input'] = query;
      final Map response =
          await sendRequest(endpoints['search_suggestions']!, body, headers);
      final List finalResult = NavClass.nav(response, [
            'contents',
            0,
            'searchSuggestionsSectionRenderer',
            'contents',
          ]) as List? ??
          [];
      final List<String> results = [];
      for (final item in finalResult) {
        results.add(
          NavClass.nav(item, [
            'searchSuggestionRenderer',
            'NavClass.navigationEndpoint',
            'searchEndpoint',
            'query',
          ]).toString(),
        );
      }
      return results;
    } catch (e) {
      Logger.root.severe('Error in yt search suggestions', e);
      return List.empty();
    }
  }

  Map? parseInfoFromSubtitle(
    Map childItem, {
    List? idNavPath,
    List? idNavPath2,
    List? imageNavPath,
    List? titleNavPath,
    List? subtitleNavPath,
  }) {
    final List images = NavClass.runUrls(
      NavClass.nav(
        childItem,
        imageNavPath ?? [NavClass.mRLIR, ...NavClass.thumbnails],
      ) as List?,
    );
    final String title = NavClass.joinRunTexts(
      NavClass.nav(
        childItem,
        titleNavPath ??
            [...NavClass.mRLIRFlex, 0, NavClass.mRLIFCR, ...NavClass.textRuns],
      ) as List?,
    );
    final String subtitle = NavClass.joinRunTexts(
      NavClass.nav(
        childItem,
        subtitleNavPath ??
            [...NavClass.mRLIRFlex, 1, NavClass.mRLIFCR, ...NavClass.textRuns],
      ) as List?,
    );

    if (title == '' && subtitle == '') return null;

    final List<String> subtitleList = subtitle.split('•');
    String type = subtitleList.first.trim();
    if (![
      'song',
      'video',
      'single',
      'album',
      'playlist',
      'artist',
      'profile',
    ].contains(type.toLowerCase())) {
      type = 'Song';
      subtitleList.insert(0, 'Song');
    }

    final List idNav = (type == 'Song' || type == 'Video')
        ? NavClass.mrlirPlaylistId
        : NavClass.mrlirBrowseId;
    final String? id =
        NavClass.nav(childItem, idNavPath ?? idNav)?.toString() ??
            NavClass.nav(childItem, idNavPath2 ?? idNav)?.toString();

    if (id == null) {
      Logger.root.info('Unable to get id for $title of type $type');
      Logger.root.info('Child item: $childItem');
    }

    final Map result = {};
    result['id'] = id;
    result['type'] = type;
    result['title'] = title;
    result['images'] = images;
    result['image'] = images.isEmpty ? '' : images.first;
    result['subtitle'] = subtitle;
    final len = subtitleList.length;

    switch (type) {
      case 'Artist':
        if (len > 1) result['subscribers'] = subtitleList[1].trim();
        result['artist'] = title;
        break;
      case 'Song':
        if (len > 1) result['artist'] = subtitleList[1].trim();
        if (len > 2) result['album'] = subtitleList[2].trim();
        if (len > 3) result['duration'] = subtitleList[3].trim();
        break;
      case 'Video':
        if (len > 1) result['artist'] = subtitleList[1].trim();
        if (len > 2) result['views'] = subtitleList[2].trim();
        if (len > 3) result['duration'] = subtitleList[3].trim();
        break;
      case 'Album':
      case 'Single':
        if (len > 1) result['artist'] = subtitleList[1].trim();
        if (len > 2) result['year'] = subtitleList[2].trim();
        break;
      case 'Playlist':
        if (len > 1) result['artist'] = subtitleList[1].trim();
        if (len > 2) result['views'] = subtitleList[2].trim();
        break;
      default:
        break;
    }

    return result;
  }

  int getDatestamp() {
    final DateTime now = DateTime.now();
    final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final Duration difference = now.difference(epoch);
    final int days = difference.inDays;
    return days;
  }

  Future<Map> getSongData({required String videoId}) async {
    if (headers == null) {
      await init();
    }
    try {
      signatureTimestamp = signatureTimestamp ?? getDatestamp() - 1;
      final body = Map.from(context!);
      body['playbackContext'] = {
        'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
      };
      body['video_id'] = videoId;
      final Map response =
          await sendRequest(endpoints['get_song']!, body, headers);
      int maxBitrate = 0;
      String? url;
      final formats =
          await NavClass.nav(response, ['streamingData', 'formats']) as List;
      for (final element in formats) {
        if (element['bitrate'] != null) {
          if (int.parse(element['bitrate'].toString()) > maxBitrate) {
            maxBitrate = int.parse(element['bitrate'].toString());
            url = element['signatureCipher'].toString();
          }
        }
      }
      // final adaptiveFormats =
      //     await NavClass.nav(response, ['streamingData', 'adaptiveFormats']) as List;
      // for (final element in adaptiveFormats) {
      //   if (element['bitrate'] != null) {
      //     if (int.parse(element['bitrate'].toString()) > maxBitrate) {
      //       maxBitrate = int.parse(element['bitrate'].toString());
      //       url = element['signatureCipher'].toString();
      //     }
      //   }
      // }
      final videoDetails =
          await NavClass.nav(response, ['videoDetails']) as Map;
      final reg = RegExp('url=(.*)');
      final matches = reg.firstMatch(url!);
      final String result = matches!.group(1).toString().unescape();
      return {
        'id': videoDetails['videoId'],
        'title': videoDetails['title'],
        'artist': videoDetails['author'],
        'duration': videoDetails['lengthSeconds'],
        'url': result,
        'views': videoDetails['viewCount'],
        'image': videoDetails['thumbnail']['thumbnails'].last['url'],
        'images': videoDetails['thumbnail']['thumbnails'].map((e) => e['url']),
      };
    } catch (e) {
      Logger.root.severe('Error in yt get song data', e);
      return {};
    }
  }

  Future<Map> getPlaylistDetails(String playlistId) async {
    if (headers == null) {
      await init();
    }
    try {
      final browseId =
          playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
      final body = Map.from(context!);
      body['browseId'] = browseId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);
      final String? heading = NavClass.nav(response, [
        'header',
        'musicDetailHeaderRenderer',
        'title',
        'runs',
        0,
        'text',
      ]) as String?;
      final String subtitle = (NavClass.nav(response, [
                'header',
                'musicDetailHeaderRenderer',
                'subtitle',
                'runs',
              ]) as List? ??
              [])
          .map((e) => e['text'])
          .toList()
          .join();
      final String? description = NavClass.nav(response, [
        'header',
        'musicDetailHeaderRenderer',
        'description',
        'runs',
        0,
        'text',
      ]) as String?;
      final List images = (NavClass.nav(response, [
        'header',
        'musicDetailHeaderRenderer',
        'thumbnail',
        'croppedSquareThumbnailRenderer',
        'thumbnail',
        'thumbnails',
      ]) as List)
          .map((e) => e['url'])
          .toList();
      final List finalResults = NavClass.nav(response, [
            'contents',
            'singleColumnBrowseResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'sectionListRenderer',
            'contents',
            0,
            'musicPlaylistShelfRenderer',
            'contents',
          ]) as List? ??
          [];
      final List<Map> songResults = [];
      for (final item in finalResults) {
        final String id = NavClass.nav(item, [
          'musicResponsiveListItemRenderer',
          'playlistItemData',
          'videoId',
        ]).toString();
        final String image = NavClass.nav(item, [
          'musicResponsiveListItemRenderer',
          'thumbnail',
          'musicThumbnailRenderer',
          'thumbnail',
          'thumbnails',
          0,
          'url',
        ]).toString();
        final String title = NavClass.nav(item, [
          'musicResponsiveListItemRenderer',
          'flexColumns',
          0,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs',
          0,
          'text',
        ]).toString();
        final List subtitleList = NavClass.nav(item, [
          'musicResponsiveListItemRenderer',
          'flexColumns',
          1,
          'musicResponsiveListItemFlexColumnRenderer',
          'text',
          'runs',
        ]) as List;
        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';
        year = '';
        for (final element in subtitleList) {
          // ignore: use_string_buffers
          subtitle += element['text'].toString();
          if (element['text'].trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }
        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album,
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': '',
          'expire_at': '0',
        });
      }
      return {
        'songs': songResults,
        'name': heading,
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': playlistId,
        'type': 'playlist',
      };
    } catch (e) {
      Logger.root.severe('Error in ytmusic getPlaylistDetails', e);
      return {};
    }
  }

  Future<Map> getAlbumDetails(String albumId) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['browseId'] = albumId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);
      final String? heading = NavClass.nav(
        response,
        [...NavClass.headerDetail, ...NavClass.titleText],
      ) as String?;
      final String subtitle = NavClass.joinRunTexts(
        NavClass.nav(response, [
              ...NavClass.headerDetail,
              ...NavClass.subtitleRuns,
            ]) as List? ??
            [],
      );
      final String description = NavClass.joinRunTexts(
        NavClass.nav(response, [
              ...NavClass.headerDetail,
              ...NavClass.secondSubtitleRuns,
            ]) as List? ??
            [],
      );
      final List images = NavClass.runUrls(
        NavClass.nav(response, [
              ...NavClass.headerDetail,
              ...NavClass.thumbnailCropped,
            ]) as List? ??
            [],
      );
      final List finalResults = NavClass.nav(response, [
            ...NavClass.singleColumnTab,
            ...NavClass.sectionListItem,
            ...NavClass.musicShelf,
            'contents',
          ]) as List? ??
          [];
      final List<Map> songResults = [];
      for (final item in finalResults) {
        final String id =
            NavClass.nav(item, NavClass.mrlirPlaylistId).toString();
        final String image = NavClass.nav(item, [
          NavClass.mRLIR,
          ...NavClass.thumbnails,
          0,
          'url',
        ]).toString();
        final String title = NavClass.nav(item, [
          NavClass.mRLIR,
          'flexColumns',
          0,
          NavClass.mRLIFCR,
          ...NavClass.textRunText,
        ]).toString();
        final List subtitleList = NavClass.nav(item, [
              NavClass.mRLIR,
              'flexColumns',
              1,
              NavClass.mRLIFCR,
              ...NavClass.textRuns,
            ]) as List? ??
            [];
        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';
        year = '';
        for (final element in subtitleList) {
          // ignore: use_string_buffers
          subtitle += element['text'].toString();
          if (element['text'].trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }
        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album,
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': '',
        });
      }
      return {
        'songs': songResults,
        'name': heading,
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': albumId,
        'type': 'album',
      };
    } catch (e) {
      Logger.root.severe('Error in ytmusic getAlbumDetails', e);
      return {};
    }
  }

  Future<Map<String, dynamic>> getArtistDetails(String id) async {
    if (headers == null) {
      await init();
    }
    String artistId = id;
    if (artistId.startsWith('MPLA')) {
      artistId = artistId.substring(4);
    }
    try {
      final body = Map.from(context!);
      body['browseId'] = artistId;
      final Map response =
          await sendRequest(endpoints['browse']!, body, headers);
      // final header = response['header']['musicImmersiveHeaderRenderer']
      final String? heading = NavClass.nav(response, [
        ...NavClass.immersiveHeaderDetail,
        ...NavClass.titleText,
      ]) as String?;
      final String subtitle = NavClass.joinRunTexts(
        NavClass.nav(response, [
              ...NavClass.immersiveHeaderDetail,
              ...NavClass.subtitleRuns,
            ]) as List? ??
            [],
      );
      final String description = NavClass.joinRunTexts(
        NavClass.nav(response, [
              ...NavClass.immersiveHeaderDetail,
              ...NavClass.secondSubtitleRuns,
            ]) as List? ??
            [],
      );
      final List images = NavClass.runUrls(
        NavClass.nav(response, [
              ...NavClass.immersiveHeaderDetail,
              ...NavClass.thumbnails,
            ]) as List? ??
            [],
      );
      final List finalResults = NavClass.nav(response, [
            ...NavClass.singleColumnTab,
            ...NavClass.sectionList,
            0,
            ...NavClass.musicShelf,
            'contents',
          ]) as List? ??
          [];
      final List<Map> songResults = [];
      for (final item in finalResults) {
        final String id =
            NavClass.nav(item, NavClass.mrlirPlaylistId).toString();
        final String image = NavClass.nav(item, [
          NavClass.mRLIR,
          ...NavClass.thumbnails,
          0,
          'url',
        ]).toString();
        final String title = NavClass.nav(item, [
          NavClass.mRLIR,
          'flexColumns',
          0,
          NavClass.mRLIFCR,
          ...NavClass.textRunText,
        ]).toString();
        final List subtitleList = NavClass.nav(item, [
              NavClass.mRLIR,
              'flexColumns',
              1,
              NavClass.mRLIFCR,
              ...NavClass.textRuns,
            ]) as List? ??
            [];
        int count = 0;
        String year = '';
        String album = '';
        String artist = '';
        String albumArtist = '';
        String duration = '';
        String subtitle = '';
        year = '';
        for (final element in subtitleList) {
          // ignore: use_string_buffers
          subtitle += element['text'].toString();
          if (element['text'].trim() == '•') {
            count++;
          } else {
            if (count == 0) {
              if (element['text'].toString().trim() == '&') {
                artist += ', ';
              } else {
                artist += element['text'].toString();
                if (albumArtist == '') {
                  albumArtist = element['text'].toString();
                }
              }
            } else if (count == 1) {
              album += element['text'].toString();
            } else if (count == 2) {
              duration += element['text'].toString();
            }
          }
        }
        songResults.add({
          'id': id,
          'type': 'song',
          'title': title,
          'artist': artist,
          'genre': 'YouTube',
          'language': 'YouTube',
          'year': year,
          'album_artist': albumArtist,
          'album': album,
          'duration': duration,
          'subtitle': subtitle,
          'image': image,
          'perma_url': 'https://www.youtube.com/watch?v=$id',
          'url': 'https://www.youtube.com/watch?v=$id',
          'release_date': '',
          'album_id': '',
        });
      }
      return {
        'songs': songResults,
        'name': heading,
        'subtitle': subtitle,
        'description': description,
        'images': images,
        'id': artistId,
        'type': 'artist',
      };
    } catch (e) {
      Logger.root.info('Error in ytmusic getArtistDetails', e);
      return {};
    }
  }

  Future<List<String>> getWatchPlaylist({
    String? videoId,
    String? playlistId,
    int limit = 25,
    bool radio = false,
    bool shuffle = false,
  }) async {
    if (headers == null) {
      await init();
    }
    try {
      final body = Map.from(context!);
      body['enablePersistentPlaylistPanel'] = true;
      body['isAudioOnly'] = true;
      body['tunerSettingValue'] = 'AUTOMIX_SETTING_NORMAL';

      if (videoId == null && playlistId == null) {
        return [];
      }
      if (videoId != null) {
        body['videoId'] = videoId;
        playlistId ??= 'RDAMVM$videoId';
        if (!(radio || shuffle)) {
          body['watchEndpointMusicSupportedConfigs'] = {
            'watchEndpointMusicConfig': {
              'hasPersistentPlaylistPanel': true,
              'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV;',
            },
          };
        }
      }
      // bool is_playlist = false;

      body['playlistId'] = playlistIdTrimmer(playlistId!);
      // is_playlist = body['playlistId'].toString().startsWith('PL') ||
      //     body['playlistId'].toString().startsWith('OLA');

      if (shuffle) body['params'] = 'wAEB8gECKAE%3D';
      if (radio) body['params'] = 'wAEB';
      final Map response = await sendRequest(endpoints['next']!, body, headers);
      final Map results = NavClass.nav(response, [
            'contents',
            'singleColumnMusicWatchNextResultsRenderer',
            'tabbedRenderer',
            'watchNextTabbedResultsRenderer',
            'tabs',
            0,
            'tabRenderer',
            'content',
            'musicQueueRenderer',
            'content',
            'playlistPanelRenderer',
          ]) as Map? ??
          {};
      final playlist = (results['contents'] as List<dynamic>).where(
        (x) =>
            NavClass.nav(x, [
              'playlistPanelVideoRenderer',
              ...NavClass.navigationPlaylistId,
            ]) !=
            null,
      );
      int count = 0;
      final List<String> songResults = [];
      for (final item in playlist) {
        if (count > 0) {
          final String id =
              NavClass.nav(item, ['playlistPanelVideoRenderer', 'videoId'])
                  .toString();
          songResults.add(id);
        } else {
          count++;
        }
      }
      return songResults;
    } catch (e) {
      Logger.root.severe('Error in ytmusic getWatchPlaylist', e);
      return [];
    }
  }
}
