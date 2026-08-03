double interpolateScrollProgress({
  required double displayed,
  required double target,
  required double factor,
}) => displayed + (target - displayed) * factor;
