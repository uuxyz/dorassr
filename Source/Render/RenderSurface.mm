/* Copyright (c) 2016-2026 Li Jin <dragon-fly@qq.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#include "Const/Header.h"

#if BX_PLATFORM_IOS

#import <SDL3/SDL.h>
#import <SDL3/SDL_properties.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>

#import "Render/RenderSurface.h"

/* Global scope: the declaration in RenderSurface.cpp is not inside the
   Dora namespace. */
void* createIOSMetalLayer(SDL_Window* window) {
	SDL_PropertiesID props = SDL_GetWindowProperties(window);
	UIWindow* uiWindow = (__bridge UIWindow*)SDL_GetPointerProperty(
		props, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
	if (!uiWindow.rootViewController) return nullptr;
	CALayer* layer = uiWindow.rootViewController.view.layer;
	CAMetalLayer* displayLayer = [[CAMetalLayer alloc] init];
	displayLayer.contentsScale = [UIScreen mainScreen].scale;
	displayLayer.frame = layer.frame;
	[layer addSublayer:displayLayer];
	[layer layoutSublayers];
	return (__bridge void*)displayLayer;
}

#endif // BX_PLATFORM_IOS
