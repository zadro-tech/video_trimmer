import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/thumbnail_viewer.dart';
import 'package:video_trimmer/video_trimmer.dart';

VideoPlayerController videoPlayerController;

class TrimEditor extends StatefulWidget {
  final double viewerWidth;

  final double viewerHeight;

  final BoxFit fit;

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
    this.fit = BoxFit.fitHeight,
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
        assert(fit != null),
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

  double maxLengthPixels;
  double minLengthPixels;

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

  double _thumbnailWidgetWidth; //缩略图的总宽度

  double _maxRegion; //滑块之间的最大距离

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
      _videoEndPos = widget.maxDuration.inMilliseconds.toDouble();

      widget.onChangeEnd(_videoEndPos);

      _thumbnailWidgetWidth = (_videoDuration / widget.maxDuration.inMilliseconds) * _maxRegion;

      //默认maxDuration对应8张缩略图
      _numberOfThumbnails = _thumbnailWidgetWidth * 8 ~/ _maxRegion;

      final ThumbnailViewer _thumbnailWidget = ThumbnailViewer(
        videoFile: _videoFile,
        videoDuration: _videoDuration,
        fit: widget.fit,
        thumbnailHeight: widget.viewerHeight,
        numberOfThumbnails: _numberOfThumbnails,
        quality: widget.thumbnailQuality,
        startSpace: _start,
        endSpace: widget.viewerWidth * 0.2,
        controller: controller,
      );
      thumbnailWidget = _thumbnailWidget;
    }
  }

  @override
  void initState() {
    super.initState();
    controller = ScrollController();

    controller.addListener(() {
      setState(() {
        double x = controller.offset / _thumbnailWidgetWidth;
        _videoStartPos = _videoDuration * (_start - _arrivedLeft) / _thumbnailWidgetWidth + _videoDuration * x;
        _videoEndPos = _videoDuration * (_end + controller.offset - (_arrivedRight - _end)) / _thumbnailWidgetWidth;
      });
    });

    _maxRegion = widget.viewerWidth * 0.8;

    _videoFile = Trimmer.currentVideoFile;

    _arrivedLeft = _start = widget.viewerWidth * 0.2;
    _arrivedRight = _end = widget.viewerWidth * 0.8;

    _initializeVideoController();

    // Defining the tween points
    _linearTween = Tween(begin: _start, end: _end);

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
                        Duration(milliseconds: _videoStartPos.toInt()).toString().split('.')[0],
                        style: widget.durationTextStyle,
                      ),
                      Text(
                        Duration(milliseconds: _videoEndPos.toInt()).toString().split('.')[0],
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
              left: _start,
              right: widget.viewerWidth - _end,
              child: Container(height: 1, color: Colors.white),
            ),
            Positioned(
              left: _start,
              right: widget.viewerWidth - _end,
              bottom: 0,
              child: Container(height: 1, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _leftSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: Colors.white,
    );

    current = GestureDetector(
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (_start + details.delta.dx < _arrivedLeft) {
          setState(() {
            _start = _arrivedLeft;
          });

          return;
        }

        setState(() {
          _start = _start + details.delta.dx;
          print('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=' +
              _start.toString());
          print('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=' +
              _arrivedLeft.toString());
          double x = (_start - _arrivedLeft) / _thumbnailWidgetWidth;
          _videoStartPos = _videoDuration * x;
        });
      },
      child: current,
    );

    return Positioned(left: _start, child: current);
  }

  Widget _rightSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: Colors.white,
    );

    current = GestureDetector(
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (_end + details.delta.dx > _arrivedRight) {
          setState(() {
            _end = _arrivedRight;
          });

          return;
        }

        setState(() {
          _end = _end + details.delta.dx;

          _videoEndPos = _videoDuration * (_end + details.localPosition.dx) / _thumbnailWidgetWidth;
        });
      },
      child: current,
    );

    return Positioned(left: _end, child: current);
  }
}
