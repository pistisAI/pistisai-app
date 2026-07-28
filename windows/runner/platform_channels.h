#ifndef PLATFORM_CHANNELS_H_
#define PLATFORM_CHANNELS_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

void RegisterPlatformChannels(flutter::PluginRegistrar* registrar);

#endif  // PLATFORM_CHANNELS_H_
