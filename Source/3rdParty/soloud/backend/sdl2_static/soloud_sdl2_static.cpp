/*
SoLoud audio engine
Copyright (c) 2013-2015 Jari Komppa

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.
*/
#include <stdlib.h>

#include "soloud.h"

#if !defined(WITH_SDL2_STATIC)

namespace SoLoud
{
	result sdl2static_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer)
	{
		return NOT_IMPLEMENTED;
	}
}

#else

#include <SDL3/SDL.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

namespace SoLoud
{
	struct SDL2StaticBackendData
	{
		SDL_AudioSpec activeAudioSpec;
		SDL_AudioStream *stream;
		SoLoud::Soloud *soloud;
		uint64_t generation;
	};

	static uint64_t gNextBackendGeneration = 0;

	/* SDL3 removed the push-style device callback. The stream callback runs on
	   SDL's audio thread and reports how many more bytes it wants; we mix that
	   many frames with SoLoud and push them into the stream, which handles
	   format conversion to the device. */
	void soloud_sdl2static_audiomixer(void *userdata, SDL_AudioStream *stream, int additional_amount, int total_amount)
	{
		(void)total_amount;
		SDL2StaticBackendData *backend = (SDL2StaticBackendData *)userdata;
		if (!backend || backend->generation == 0 || !backend->soloud)
			return;
		if (additional_amount <= 0)
			return;
		const int bytesPerFrame = backend->activeAudioSpec.channels * (int)sizeof(float);
		int frames = additional_amount / bytesPerFrame;
		while (frames > 0)
		{
			float mixBuffer[2048 * 2];
			const int chunk = frames < 2048 ? frames : 2048;
			if (backend->activeAudioSpec.format != SDL_AUDIO_F32)
			{
				/* Format conversions are handled by the stream; only feed F32. */
				return;
			}
			backend->soloud->mix(mixBuffer, chunk);
			if (!SDL_PutAudioStreamData(stream, mixBuffer, chunk * bytesPerFrame))
				return;
			frames -= chunk;
		}
	}

	static void soloud_sdl2static_deinit(SoLoud::Soloud *aSoloud)
	{
		SDL2StaticBackendData *backend = (SDL2StaticBackendData *)aSoloud->mBackendData;
		if (!backend)
			return;
		if (backend->stream)
		{
			// SDL holds the device lock while invoking the callback. Locking the
			// stream here waits for an in-flight mix and makes every later
			// callback observe the zeroed generation.
			SDL_LockAudioStream(backend->stream);
			backend->generation = 0;
			backend->soloud = NULL;
			SDL_UnlockAudioStream(backend->stream);
			SDL_DestroyAudioStream(backend->stream);
			backend->stream = NULL;
		}
		aSoloud->mBackendData = NULL;
		delete backend;
	}

	result sdl2static_init(SoLoud::Soloud *aSoloud, unsigned int aFlags, unsigned int aSamplerate, unsigned int aBuffer, unsigned int aChannels)
	{
		if (!SDL_WasInit(SDL_INIT_AUDIO))
		{
			if (!SDL_InitSubSystem(SDL_INIT_AUDIO))
			{
				SDL_LogError(SDL_LOGCATEGORY_APPLICATION,
					"SoLoud SDL3 backend: SDL_InitSubSystem(SDL_INIT_AUDIO) failed: %s",
					SDL_GetError());
				return UNKNOWN_ERROR;
			}
		}

		SDL2StaticBackendData *backend = new SDL2StaticBackendData();
		memset(backend, 0, sizeof(*backend));
		backend->soloud = aSoloud;
		backend->generation = ++gNextBackendGeneration;

		SDL_AudioSpec as;
		memset(&as, 0, sizeof(as));
		as.freq = aSamplerate;
		as.format = SDL_AUDIO_F32;
		as.channels = aChannels;

		backend->stream = SDL_OpenAudioDeviceStream(
			SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &as,
			soloud_sdl2static_audiomixer, backend);
		if (backend->stream == NULL)
		{
			SDL_LogError(SDL_LOGCATEGORY_APPLICATION,
				"SoLoud SDL3 backend: failed to open the default playback device (%u Hz, %u ch): %s",
				as.freq, as.channels, SDL_GetError());
			delete backend;
			return UNKNOWN_ERROR;
		}
		SDL_GetAudioStreamFormat(backend->stream, &backend->activeAudioSpec, NULL);

		aSoloud->postinit_internal(backend->activeAudioSpec.freq, aBuffer, aFlags, backend->activeAudioSpec.channels);

		aSoloud->mBackendData = backend;
		aSoloud->mBackendCleanupFunc = soloud_sdl2static_deinit;

		SDL_ResumeAudioStreamDevice(backend->stream);
		aSoloud->mBackendString = "SDL3 (static)";
		return 0;
	}	
};
#endif
