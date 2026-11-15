import 'dart:async';

import 'package:flutter/material.dart';

/// How long the current turn has been going, refreshed every second: "0:07",
/// "12:30", or "1:02:05" past an hour. [elapsed] does the timing, so a paused
/// turn simply stops changing.
class TurnClock extends StatefulWidget {
  const TurnClock({super.key, required this.elapsed, this.style});

  final ValueGetter<Duration> elapsed;
  final TextStyle? style;

  static String format(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  @override
  State<TurnClock> createState() => _TurnClockState();
}

class _TurnClockState extends State<TurnClock> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      TurnClock.format(widget.elapsed()),
      key: const ValueKey('turn-clock'),
      style: widget.style,
    );
  }
}
