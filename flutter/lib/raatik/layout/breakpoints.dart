enum RaatikWindowClass { compact, medium, wide }

RaatikWindowClass raatikWindowClassFor(double width) {
  if (width < 900) return RaatikWindowClass.compact;
  if (width < 1200) return RaatikWindowClass.medium;
  return RaatikWindowClass.wide;
}
