import '../theme/tokens.dart';

enum RaatikWindowClass { compact, medium, wide }

RaatikWindowClass raatikWindowClassFor(double width) {
  if (width < RaatikTokens.compactMax) return RaatikWindowClass.compact;
  if (width < RaatikTokens.mediumMax) return RaatikWindowClass.medium;
  return RaatikWindowClass.wide;
}
