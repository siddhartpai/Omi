import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:friend_private/backend/api_requests/api/other.dart';
import 'package:friend_private/backend/mixpanel.dart';
import 'package:friend_private/backend/preferences.dart';
import 'package:friend_private/backend/schema/bt_device.dart';
import 'package:friend_private/pages/capture/widgets/widgets.dart';
import 'package:friend_private/pages/speaker_id/page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'widgets/transcript.dart';

class CapturePage extends StatefulWidget {
  final Function refreshMemories;
  final Function refreshMessages;
  final BTDeviceStruct? device;

  final GlobalKey<TranscriptWidgetState> transcriptChildWidgetKey;

  const CapturePage({
    super.key,
    required this.device,
    required this.refreshMemories,
    required this.transcriptChildWidgetKey,
    required this.refreshMessages,
  });

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with AutomaticKeepAliveClientMixin {
  bool _hasTranscripts = false;
  final record = AudioRecorder();

  RecordState _state = RecordState.stop;

  @override
  bool get wantKeepAlive => true;

  _startRecording() async {
    record.onStateChanged().listen((event) {
      debugPrint('event: $event');
      setState(() => _state = event);
    });
    debugPrint('_startRecording: ${await record.hasPermission()}');
    if (await record.hasPermission()) {
      // Start recording to file
      var path = await getApplicationDocumentsDirectory();
      debugPrint(path.toString());
      // await record.cancel();
      await record.start(
        const RecordConfig(numChannels: 1),
        path: '${path.path}/recording.m4a',
      );
    }
  }

  @override
  void dispose() {
    record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(children: [
          SharedPreferencesUtil().hasSpeakerProfile
              ? const SizedBox(height: 16)
              : Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (c) => const SpeakerIdPage()));
                        MixpanelManager().speechProfileCapturePageClicked();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.multitrack_audio),
                                  SizedBox(width: 16),
                                  Text(
                                    'Set up speech profile',
                                    style: TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios)
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 24,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
          ...getConnectedDeviceWidgets(_hasTranscripts, widget.device),
          TranscriptWidget(
              btDevice: widget.device,
              key: widget.transcriptChildWidgetKey,
              refreshMemories: widget.refreshMemories,
              refreshMessages: widget.refreshMessages,
              setHasTranscripts: (hasTranscripts) {
                if (_hasTranscripts == hasTranscripts) return;
                setState(() {
                  _hasTranscripts = hasTranscripts;
                });
              }),
          const SizedBox(height: 16)
        ]),
        _getPhoneMicRecordingButton()
      ],
    );
  }

  _getPhoneMicRecordingButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 140),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: MaterialButton(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _state == RecordState.record ? Colors.red : Colors.white)),
          onPressed: _recordingToggled,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _state == RecordState.record
                    ? const Icon(Icons.stop, color: Colors.red, size: 24)
                    : const Icon(Icons.mic),
                const SizedBox(width: 8),
                Text(_state == RecordState.record ? 'Stop Recording' : 'Try With Phone Mic'),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _recordingToggled() async {
    debugPrint('await record.isRecording(): ${await record.isRecording()}');
    if (await record.isRecording()) {
      await record.stop();
      setState(() => _state == RecordState.stop);
      var file = File('${(await getApplicationDocumentsDirectory()).path}/recording.m4a');
      int bytes = await file.length();
      var i = (log(bytes) / log(1024)).floor();
      const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
      var size = '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
      debugPrint('File size: $size');
      var segments = await transcribeAudioFile2(file);
      debugPrint('segments: $segments');
    } else {
      setState(() => _state == RecordState.record);
      _startRecording();
    }
  }
}
