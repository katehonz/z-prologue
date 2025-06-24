# Configuration for performance examples

# Enable optimizations
switch("opt", "speed")
switch("gc", "arc")

# Enable threading for better performance
switch("threads", "on")

# Enable debug info for profiling
switch("debuginfo", "on")

# Disable bounds checking for better performance in release
when defined(release):
  switch("boundChecks", "off")
  switch("overflowChecks", "off")

# Link with required libraries
when defined(linux):
  switch("passL", "-lpthread")

# Set stack size for async operations
switch("stackTrace", "on")
switch("lineTrace", "on")