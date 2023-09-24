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

import 'package:blackhole/CustomWidgets/empty_screen.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/image_card.dart';
import 'package:blackhole/CustomWidgets/like_button.dart';
import 'package:blackhole/Services/player_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';

class RecentlyPlayed extends StatefulWidget {
  @override
  _RecentlyPlayedState createState() => _RecentlyPlayedState();
}

class _RecentlyPlayedState extends State<RecentlyPlayed> {
  List _songs = [];
  bool added = false;

  Future<void> getSongs() async {
    _songs = Hive.box('cache').get('recentSongs', defaultValue: []) as List;
    added = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!added) {
      getSongs();
    }

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.lastSession),
          centerTitle: true,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.transparent
              : Theme.of(context).colorScheme.secondary,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                Hive.box('cache').put('recentSongs', []);
                setState(() {
                  _songs = [];
                });
              },
              tooltip: AppLocalizations.of(context)!.clearAll,
              icon: const Icon(Icons.clear_all_rounded),
            ),
          ],
        ),
        body: _songs.isEmpty
            ? emptyScreen(
                context,
                3,
                AppLocalizations.of(context)!.nothingTo,
                15,
                AppLocalizations.of(context)!.showHere,
                50.0,
                AppLocalizations.of(context)!.playSomething,
                23.0,
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                shrinkWrap: true,
                itemCount: _songs.length,
                itemExtent: 70.0,
                itemBuilder: (context, index) {
                  return _songs.isEmpty
                      ? const SizedBox()
                      : Dismissible(
                          key: Key(_songs[index]['id'].toString()),
                          direction: DismissDirection.endToStart,
                          background: const ColoredBox(
                            color: Colors.redAccent,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 15.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete_outline_rounded),
                                ],
                              ),
                            ),
                          ),
                          onDismissed: (direction) {
                            _songs.removeAt(index);
                            setState(() {});
                            Hive.box('cache').put('recentSongs', _songs);
                          },
                          child: ListTile(
                            leading: imageCard(
                              imageUrl: _songs[index]['image'].toString(),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // DownloadButton(
                                //   data: _songs[index] as Map,
                                //   icon: 'download',
                                // ),
                                LikeButton(
                                  mediaItem: null,
                                  data: _songs[index] as Map,
                                ),
                              ],
                            ),
                            title: Text(
                              '${_songs[index]["title"]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_songs[index]["artist"]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              PlayerInvoke.init(
                                songsList: _songs,
                                index: index,
                                isOffline: false,
                              );
                            },
                          ),
                        );
                },
              ),
      ),
    );
  }
}
