import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/thumbnail_viewer.dart';
import 'package:video_trimmer/video_trimmer.dart';

VideoPlayerController videoPlayerController;

class TrimEditor extends StatefulWidget {
  final double viewerWidth;

  final double viewerHeight;

  final Duration maxDuration;

  final Duration minDuration;

  final Color scrubberPaintColor;

  final int thumbnailQuality;

  final bool showDuration;

  final TextStyle durationTextStyle;

  final Function(double startValue) onChangeStart;

  final Function(double endValue) onChangeEnd;

  final Function(bool isPlaying) onChangePlaybackState;

  TrimEditor({
    @required this.viewerWidth,
    @required this.viewerHeight,
    @required this.maxDuration,
    @required this.minDuration,
    this.scrubberPaintColor = Colors.white,
    this.thumbnailQuality = 75,
    this.showDuration = true,
    this.durationTextStyle = const TextStyle(color: Colors.white),
    this.onChangeStart,
    this.onChangeEnd,
    this.onChangePlaybackState,
  })  : assert(viewerWidth != null),
        assert(viewerHeight != null),
        assert(scrubberPaintColor != null),
        assert(thumbnailQuality != null),
        assert(showDuration != null),
        assert(durationTextStyle != null);

  @override
  _TrimEditorState createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> with TickerProviderStateMixin {
  File _videoFile;

  double _videoStartPos = 0.0; //视频开始截取的时间
  double _videoEndPos = 0.0; //视频结束截取的时间

  int _videoDuration = 0; //视频的时长
  int _currentPosition = 0;

  int _numberOfThumbnails = 0; //生成缩略图的张数

  double _minLengthPixels;

  double _start; //左边滑块的位置
  double _end; //右边滑块的位置
  double _sliderLength = 10.0; //滑块的宽度

  double _arrivedLeft; //滑块到达最左边位置
  double _arrivedRight; //滑块到达最右边位置

  ThumbnailViewer thumbnailWidget;

  Animation<double> _scrubberAnimation;
  AnimationController _animationController;
  Tween<double> _linearTween;

  ScrollController controller; //缩略图滚动控制器

  double _maxRegion; //滑块之间的最大距离

  double _fraction;
  double _offset = 0;

  Future<void> _initializeVideoController() async {
    if (_videoFile != null) {
      videoPlayerController.addListener(() {
        final bool isPlaying = videoPlayerController.value.isPlaying;

        if (isPlaying) {
          widget.onChangePlaybackState(true);
          setState(() {
            _currentPosition = videoPlayerController.value.position.inMilliseconds;

            if (_currentPosition > _videoEndPos.toInt()) {
              widget.onChangePlaybackState(false);
              videoPlayerController.pause();
              _animationController.stop();
            } else {
              if (!_animationController.isAnimating) {
                widget.onChangePlaybackState(true);
                _animationController.forward();
              }
            }
          });
        } else {
          if (videoPlayerController.value.initialized) {
            if (_animationController != null) {
              if ((_scrubberAnimation.value).toInt() == (_end).toInt()) {
                _animationController.reset();
              }
              _animationController.stop();
              widget.onChangePlaybackState(false);
            }
          }
        }
      });

      videoPlayerController.setVolume(1.0);

      _videoDuration = videoPlayerController.value.duration.inMilliseconds;

      _videoStartPos = 0.0;
      widget.onChangeStart(_videoStartPos);

      _videoEndPos = widget.maxDuration.inMilliseconds.toDouble();
      if (videoPlayerController.value.duration <= widget.maxDuration)
        _videoEndPos = videoPlayerController.value.duration.inMilliseconds.toDouble();

      widget.onChangeEnd(_videoEndPos);

      //默认maxDuration对应10张缩略图
      _numberOfThumbnails = (_videoDuration ~/ widget.maxDuration.inMilliseconds) * 10;
      double _thumbnailWidth;

      if (_numberOfThumbnails <= 10) //上传的视频时长不大于最大时长
      {
        _numberOfThumbnails = 10;
        _thumbnailWidth = _maxRegion / 10;
      }

      final ThumbnailViewer _thumbnailWidget = ThumbnailViewer(
        videoFile: _videoFile,
        videoDuration: _videoDuration,
        thumbnailHeight: widget.viewerHeight,
        thumbnailWidth: _thumbnailWidth,
        numberOfThumbnails: _numberOfThumbnails,
        quality: widget.thumbnailQuality,
        startSpace: _start,
        endSpace: widget.viewerWidth * 0.1,
        controller: controller,
      );
      thumbnailWidget = _thumbnailWidget;
    }
  }

  _scrollerListener() {
    controller.addListener(() async {
      setState(() {
        _offset = controller.offset;
        _videoStartPos = (_start - _arrivedLeft + controller.offset) * _fraction;
        _videoEndPos = (_end - _arrivedLeft + controller.offset) * _fraction;

        _linearTween.begin = _start + _sliderLength;
        _linearTween.end = _end;
        _animationController.duration = Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
        _animationController.reset();

        widget.onChangeStart(_videoStartPos);
        widget.onChangeEnd(_videoEndPos);
      });

      await videoPlayerController.pause();
      await videoPlayerController.seekTo(Duration(milliseconds: _videoStartPos.toInt()));
    });
  }

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    _scrollerListener();

    _maxRegion = widget.viewerWidth * 0.8;
    _arrivedLeft = _start = widget.viewerWidth * 0.1;
    _arrivedRight = _end = widget.viewerWidth * 0.9;

    _videoFile = Trimmer.currentVideoFile;

    _initializeVideoController();

    if (_videoDuration > widget.maxDuration.inMilliseconds) {
      _fraction = widget.maxDuration.inMilliseconds / _maxRegion;
    } else {
      _fraction = _videoDuration / _maxRegion;
    }

    _minLengthPixels = (widget.minDuration.inMilliseconds / widget.maxDuration.inMilliseconds) * _maxRegion;

    // Defining the tween points
    _linearTween = Tween(begin: _start + _sliderLength, end: _end);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt()),
    );

    _scrubberAnimation = _linearTween.animate(_animationController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.stop();
        }
      });
  }

  @override
  void dispose() {
    videoPlayerController.pause();
    widget.onChangePlaybackState(false);
    if (_videoFile != null) {
      videoPlayerController.setVolume(0.0);
      videoPlayerController.pause();
      videoPlayerController.dispose();
      widget.onChangePlaybackState(false);
    }
    controller?.dispose();
    super.dispose();
  }

  String formatTime(Duration duration) {
    String str = duration.toString();

    int p = int.parse(str.split('.')[1].substring(0, 1));

    int seconds = duration.inSeconds;

    if (p >= 5) seconds = seconds + 1;

    return Duration(seconds: seconds).toString().split('.')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        widget.showDuration
            ? Container(
                width: widget.viewerWidth,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Text(
                        formatTime(Duration(milliseconds: _videoStartPos.toInt())),
                        style: widget.durationTextStyle,
                      ),
                      Text(
                        formatTime(Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt())),
                        style: widget.durationTextStyle,
                      ),
                      Text(
                        formatTime(Duration(milliseconds: _videoEndPos.toInt())),
                        style: widget.durationTextStyle,
                      ),
                    ],
                  ),
                ),
              )
            : Container(),
        Stack(
          children: [
            Container(
              height: widget.viewerHeight,
              width: widget.viewerWidth,
              child: thumbnailWidget == null ? Column() : thumbnailWidget,
            ),
            _leftSlider(),
            _rightSlider(),
            Positioned(
              top: 0,
              left: _start + _sliderLength,
              right: widget.viewerWidth - _end,
              child: Container(height: 1, color: Colors.white),
            ),
            Positioned(
              left: _start + _sliderLength,
              right: widget.viewerWidth - _end,
              bottom: 0,
              child: Container(height: 1, color: Colors.white),
            ),
            Positioned(
              left: _scrubberAnimation.value,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: _scrubberAnimation.value <= (_start + _sliderLength + 1)
                    ? Colors.transparent
                    : videoPlayerController.value.isPlaying ? Colors.yellow : Colors.yellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _dragLeft = false;

  Widget _leftSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: _dragLeft ? Colors.yellow : Colors.white,
    );

    current = GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _dragLeft = true;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _dragLeft = false;
        });
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) async {
        if (_start + details.delta.dx < _arrivedLeft) {
          setState(() {
            _start = _arrivedLeft;
          });

          return;
        }

        if (_end - _start - details.delta.dx < _minLengthPixels) return;

        setState(() {
          _start = _start + details.delta.dx;
          _videoStartPos = _fraction * (_start + _offset - _arrivedLeft);
          widget.onChangeStart(_videoStartPos);
        });

        await videoPlayerController.pause();
        await videoPlayerController.seekTo(Duration(milliseconds: _videoStartPos.toInt()));

        _linearTween.begin = _start + _sliderLength;
        _animationController.duration = Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
        _animationController.reset();
      },
      child: current,
    );

    return Positioned(left: _start, child: current);
  }

  bool _dragRight = false;
  Widget _rightSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: _dragRight ? Colors.yellow : Colors.white,
    );

    current = GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _dragRight = true;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _dragRight = false;
        });
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) async {
        if (_end + details.delta.dx > _arrivedRight) {
          setState(() {
            _end = _arrivedRight;
            _videoEndPos = _fraction * (_end - _arrivedLeft);
          });

          return;
        }

        if (_end - _start + details.delta.dx < _minLengthPixels) return;

        setState(() {
          _end = _end + details.delta.dx;
          _videoEndPos = _fraction * (_end + _offset - _arrivedLeft);

          widget.onChangeEnd(_videoEndPos);
        });

        await videoPlayerController.pause();
        await videoPlayerController.seekTo(Duration(milliseconds: _videoEndPos.toInt()));

        _linearTween.end = _end;
        _animationController.duration = Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
        _animationController.reset();
      },
      child: current,
    );

    return Positioned(left: _end, child: current);
  }
}
