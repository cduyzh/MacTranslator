//
// CountryFlagAssets.swift
// cduyzhTranslatorCore
//
// 矢量圆形国旗资源库（基于开源 Circle Flags / MIT License）
// https://github.com/HatScripts/circle-flags
//

import SwiftUI
import AppKit

public enum CountryFlagAssets {
    /// 语言代码到国旗资产标识的映射表
    public static let languageToCountryCode: [String: String] = [
        "auto": "un",
        "zh-CN": "cn",
        "zh": "cn",
        "zh-Hans": "cn",
        "zh-TW": "tw",
        "zh-Hant": "tw",
        "zh-HK": "hk",
        "en": "us",
        "en-US": "us",
        "en-GB": "gb",
        "ja": "jp",
        "ko": "kr",
        "fr": "fr",
        "de": "de",
        "es": "es",
        "ru": "ru",
        "it": "it",
        "pt": "pt",
        "pt-BR": "br",
        "ar": "sa",
        "vi": "vn",
        "th": "th",
        "id": "id",
        "hi": "in",
        "tr": "tr",
        "nl": "nl",
        "pl": "pl",
        "uk": "ua",
        "sv": "se",
        "da": "dk",
        "fi": "fi",
        "no": "no",
        "cs": "cz",
        "el": "gr",
        "hu": "hu",
        "ro": "ro",
        "ms": "my",
        "fil": "ph",
        "tl": "ph",
        "he": "il",
        "fa": "ir",
    ]

    /// 预置的开源矢量圆形国旗 SVG 资源表 (Circle Flags, MIT License)
    public static let svgs: [String: String] = [
        "un": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#338af3\" d=\"M0 0h512v512H0z\"/><circle cx=\"256\" cy=\"256\" r=\"145\" fill=\"#eee\"/><circle cx=\"256\" cy=\"256\" r=\"111\" fill=\"#338af3\"/><path fill=\"#338af3\" d=\"M76 76h360L256 256z\"/><circle cx=\"256\" cy=\"256\" r=\"89\" fill=\"#eee\"/><circle cx=\"256\" cy=\"256\" r=\"69\" fill=\"#338af3\"/><path fill=\"#eee\" d=\"M246 178h20v156h-20z\"/><path fill=\"#eee\" d=\"M334 246v20H178v-20z\"/><path fill=\"#eee\" d=\"m304 193.7 14.2 14.2-110.3 110.3-14.2-14.1z\"/><path fill=\"#eee\" d=\"m318.2 304-14.1 14.2-110.4-110.3 14.2-14.2z\"/><circle cx=\"256\" cy=\"256\" r=\"44\" fill=\"#eee\"/><circle cx=\"256\" cy=\"256\" r=\"22\" fill=\"#338af3\"/><ellipse cx=\"256\" cy=\"412\" fill=\"#eee\" rx=\"44\" ry=\"40\"/><path fill=\"#338af3\" d=\"m256 407-78 63h156z\"/></g></svg>",
        "cn": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h512v512H0z\"/><path fill=\"#ffda44\" d=\"m140.1 155.8 22.1 68h71.5l-57.8 42.1 22.1 68-57.9-42-57.9 42 22.2-68-57.9-42.1H118zm163.4 240.7-16.9-20.8-25 9.7 14.5-22.5-16.9-20.9 25.9 6.9 14.6-22.5 1.4 26.8 26 6.9-25.1 9.6zm33.6-61 8-25.6-21.9-15.5 26.8-.4 7.9-25.6 8.7 25.4 26.8-.3-21.5 16 8.6 25.4-21.9-15.5zm45.3-147.6L370.6 212l19.2 18.7-26.5-3.8-11.8 24-4.6-26.4-26.6-3.8 23.8-12.5-4.6-26.5 19.2 18.7zm-78.2-73-2 26.7 24.9 10.1-26.1 6.4-1.9 26.8-14.1-22.8-26.1 6.4 17.3-20.5-14.2-22.7 24.9 10.1z\"/></g></svg>",
        "tw": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 256 256 0h256v512H0z\"/><path fill=\"#0052b4\" d=\"M256 256V0H0v256z\"/><path fill=\"#eee\" d=\"m222.6 149.8-31.3 14.7 16.7 30.3-34-6.5-4.3 34.3-23.6-25.2-23.7 25.2-4.3-34.3-34 6.5 16.7-30.3-31.2-14.7 31.2-14.7-16.6-30.3 34 6.5 4.2-34.3 23.7 25.3L169.7 77l4.3 34.3 34-6.5-16.7 30.3z\"/><circle cx=\"146.1\" cy=\"149.8\" r=\"47.7\" fill=\"#0052b4\"/><circle cx=\"146.1\" cy=\"149.8\" r=\"41.5\" fill=\"#eee\"/></g></svg>",
        "hk": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h512v512H0z\"/><path fill=\"#eee\" d=\"M282.4 193.7c-5.8 24.2-16.1 19.6-21.2 40.7a55.7 55.7 0 0 1 26-108.3c-10.1 42.2.4 46-4.8 67.6zM205 211.6c21.2 13 13.6 21.4 32.1 32.8a55.7 55.7 0 0 1-94.9-58.2c37 22.7 43.8 13.8 62.8 25.4zm-7 79.3c19-16.2 24.7-6.4 41.2-20.4a55.7 55.7 0 0 1-84.7 72.2c33-28.2 26.6-37.4 43.6-51.8zm73.4 31c-9.6-23 1.5-25.3-6.8-45.3a55.7 55.7 0 0 1 42.6 102.8c-16.6-40-27.3-36.9-35.8-57.4zm52.2-60c-24.9 2-23.7-9.3-45.3-7.6a55.7 55.7 0 0 1 111-8.7c-43.3 3.4-43.6 14.5-65.7 16.3z\"/></g></svg>",
        "us": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M256 0h256v64l-32 32 32 32v64l-32 32 32 32v64l-32 32 32 32v64l-256 32L0 448v-64l32-32-32-32v-64z\"/><path fill=\"#d80027\" d=\"M224 64h288v64H224Zm0 128h288v64H256ZM0 320h512v64H0Zm0 128h512v64H0Z\"/><path fill=\"#0052b4\" d=\"M0 0h256v256H0Z\"/><path fill=\"#eee\" d=\"m187 243 57-41h-70l57 41-22-67zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67zm162-81 57-41h-70l57 41-22-67zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67Zm162-82 57-41h-70l57 41-22-67Zm-81 0 57-41H93l57 41-22-67zm-81 0 57-41H12l57 41-22-67Z\"/></g></svg>",
        "gb": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"m0 0 8 22-8 23v23l32 54-32 54v32l32 48-32 48v32l32 54-32 54v68l22-8 23 8h23l54-32 54 32h32l48-32 48 32h32l54-32 54 32h68l-8-22 8-23v-23l-32-54 32-54v-32l-32-48 32-48v-32l-32-54 32-54V0l-22 8-23-8h-23l-54 32-54-32h-32l-48 32-48-32h-32l-54 32L68 0H0z\"/><path fill=\"#0052b4\" d=\"M336 0v108L444 0Zm176 68L404 176h108zM0 176h108L0 68ZM68 0l108 108V0Zm108 512V404L68 512ZM0 444l108-108H0Zm512-108H404l108 108Zm-68 176L336 404v108z\"/><path fill=\"#d80027\" d=\"M0 0v45l131 131h45L0 0zm208 0v208H0v96h208v208h96V304h208v-96H304V0h-96zm259 0L336 131v45L512 0h-45zM176 336 0 512h45l131-131v-45zm160 0 176 176v-45L381 336h-45z\"/></g></svg>",
        "jp": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 0h512v512H0z\"/><circle cx=\"256\" cy=\"256\" r=\"111.3\" fill=\"#d80027\"/></g></svg>",
        "kr": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 0h512v512H0Z\"/><path fill=\"#333\" d=\"m350 335 24-24 16 16-24 23zm-39 39 24-24 15 16-23 24zm87 8 23-24 16 16-24 24zm-40 39 24-23 16 15-24 24Zm16-63 24-23 15 15-23 24zm-39 40 23-24 16 16-24 23zm63-221-63-63 15-15 64 63zm-63-15-24-24 16-16 23 24zm39 39-24-24 16-15 24 23zm8-87-24-23 16-16 24 24Zm39 40-23-24 15-16 24 24ZM91 358l63 63-16 16-63-63zm63 16 23 24-15 15-24-23zm-40-39 24 23-16 16-23-24zm24-24 63 63-16 16-63-63zm16-220-63 63-16-16 63-63zm23 23-63 63-15-16 63-63zm24 24-63 63-16-16 63-63z\"/><path fill=\"#d80027\" d=\"M319 319 193 193a89 89 0 1 1 126 126z\"/><path fill=\"#0052b4\" d=\"M319 319a89 89 0 1 1-126-126z\"/><circle cx=\"224.5\" cy=\"224.5\" r=\"44.5\" fill=\"#d80027\"/><circle cx=\"287.5\" cy=\"287.5\" r=\"44.5\" fill=\"#0052b4\"/></g></svg>",
        "fr": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z\"/><path fill=\"#0052b4\" d=\"M0 0h167v512H0z\"/><path fill=\"#d80027\" d=\"M345 0h167v512H345z\"/></g></svg>",
        "de": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#ffda44\" d=\"m0 345 256.7-25.5L512 345v167H0z\"/><path fill=\"#d80027\" d=\"m0 167 255-23 257 23v178H0z\"/><path fill=\"#333\" d=\"M0 0h512v167H0z\"/></g></svg>",
        "es": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#ffda44\" d=\"m0 128 256-32 256 32v256l-256 32L0 384Z\"/><path fill=\"#eee\" d=\"M196 168q-11 1-15 11l-5-1q-15 1-16 16c-1 15 7 16 16 16q11 0 15-11a16 16 0 0 0 17-4 16 16 0 0 0 17 4 16 16 0 1 0 10-20 16 16 0 0 0-27-5q-4-6-12-6m0 8q8 1 8 8 0 8-8 8-7 0-8-8 1-7 8-8m24 0q8 1 8 8 0 8-8 8-7 0-8-8 1-7 8-8m-44 10 4 1 4 8q-1 7-8 7-9 0-8-8 1-7 8-8m64 0q8 1 8 8 0 8-8 8-7 0-8-7l4-8zm-112 38v80h16v-80zm80 0v40c-26 0-48 14-48 32s22 32 48 32 48-14 48-32v-72zm64 0v80h16v-80z\"/><path fill=\"#ff9811\" d=\"M200 160h16v32h-16z\"/><path fill=\"#d80027\" d=\"M0 0v128h512V0zm208 184c-22 0-40 11-40 24l8 8h64l8-8c0-13-18-24-40-24m-72 8a8 8 0 0 0-8 8v8a8 8 0 1 0 16 0v-8a8 8 0 0 0-8-8m144 0a8 8 0 0 0-8 8v8a8 8 0 1 0 16 0v-8a8 8 0 0 0-8-8m-120 32v24h-38a4 4 0 0 0-4 4 4 4 0 0 0 4 4h38v40a24 24 0 0 0 24 24 24 24 0 0 0 24-24 24 24 0 0 0 24 24 24 24 0 0 0 24-24v-24h-48v-48zm72 8a10 10 0 0 0-10 10v12a10 10 0 1 0 20 0v-12a10 10 0 0 0-10-10m24 16v8h38a4 4 0 0 0 4-4 4 4 0 0 0-4-4zm-134 24a4 4 0 0 0-4 4 4 4 0 0 0 4 4h28a4 4 0 0 0 4-4 4 4 0 0 0-4-4zm144 0a4 4 0 0 0-4 4 4 4 0 0 0 4 4h28a4 4 0 0 0 4-4 4 4 0 0 0-4-4zM0 384v128h512V384z\"/><path fill=\"#ffda44\" d=\"M186 196a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6m22 0a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6m22 0a6 6 0 0 0-6 6 6 6 0 0 0 6 6 6 6 0 0 0 6-6 6 6 0 0 0-6-6\"/><path fill=\"#ff9811\" d=\"M128 208a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm-96 8v8h64v-8zm-8 16v8h8v16h-8v8h32v-8h-8v-16h8v-8zm-8 40v24q1 12 9 19v-43zm19 0v47h10v-47zm20 0v43q9-7 9-19v-24zm-71 32a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16z\"/><path fill=\"#338af3\" d=\"M208 256a16 16 0 0 0-16 16 16 16 0 0 0 16 16 16 16 0 0 0 16-16 16 16 0 0 0-16-16m-80 64a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16zm144 0a8 8 0 1 0 0 16h16a8 8 0 1 0 0-16z\"/></g></svg>",
        "ru": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#0052b4\" d=\"M512 170v172l-256 32L0 342V170l256-32z\"/><path fill=\"#eee\" d=\"M512 0v170H0V0Z\"/><path fill=\"#d80027\" d=\"M512 342v170H0V342Z\"/></g></svg>",
        "it": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z\"/><path fill=\"#6da544\" d=\"M0 0h167v512H0z\"/><path fill=\"#d80027\" d=\"M345 0h167v512H345z\"/></g></svg>",
        "pt": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#6da544\" d=\"M0 512h167l37.9-260.3L167 0H0z\"/><path fill=\"#d80027\" d=\"M512 0H167v512h345z\"/><circle cx=\"167\" cy=\"256\" r=\"89\" fill=\"#ffda44\"/><path fill=\"#d80027\" d=\"M116.9 211.5V267a50 50 0 1 0 100.1 0v-55.6H117z\"/><path fill=\"#eee\" d=\"M167 283.8c-9.2 0-16.7-7.5-16.7-16.7V245h33.4v22c0 9.2-7.5 16.7-16.7 16.7z\"/></g></svg>",
        "br": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#6da544\" d=\"M0 0h512v512H0z\"/><path fill=\"#ffda44\" d=\"M256 100.2 467.5 256 256 411.8 44.5 256z\"/><path fill=\"#eee\" d=\"M174.2 221a87 87 0 0 0-7.2 36.3l162 49.8a88.5 88.5 0 0 0 14.4-34c-40.6-65.3-119.7-80.3-169.1-52z\"/><path fill=\"#0052b4\" d=\"M255.7 167a89 89 0 0 0-41.9 10.6 89 89 0 0 0-39.6 43.4 181.7 181.7 0 0 1 169.1 52.2 89 89 0 0 0-9-59.4 89 89 0 0 0-78.6-46.8zM212 250.5a149 149 0 0 0-45 6.8 89 89 0 0 0 10.5 40.9 89 89 0 0 0 120.6 36.2 89 89 0 0 0 30.7-27.3A151 151 0 0 0 212 250.5z\"/></g></svg>",
        "sa": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#496e2d\" d=\"M0 0h512v512H0Z\"/><path fill=\"#eee\" d=\"M336 356v16H128l24 24h184v16h16v-16h32v-24h-32v-16zM131.4 174v41.4h-15.8v-26.7H97.8q-6.3 0-10.8 2.3a15 15 0 0 0-6.7 6.4 22 22 0 0 0-2.3 10.5q0 6 2.3 10.3 2.3 4 6.7 6 4.5 2.1 10.8 2.1H173V174h-13v41.4h-15.8V174zm52.9 0v52.3h12.8V174zm55.3 0v41.4h-11v-31h-12.8v31h-9.3v10.9h45.9V174zm24.3 0v52.3h12.8V174zm77.8 0v41.4H326v-26.7h-17.8q-6.3 0-10.8 2.3a15 15 0 0 0-6.7 6.4 22 22 0 0 0-2.3 10.5q0 6 2.3 10.3 2.3 4 6.7 6 4.5 2.1 10.8 2.1h46.5V174zm24.2 0v52.3h12.8V174zm55.3 0v41.4h-11v-31h-12.8v31h-9.3v10.9h46V174ZM97.8 199.6h5v15.8h-5q-2.4 0-4-.4-1.5-.5-2.2-2a13 13 0 0 1-.8-5.1q0-3.7.8-5.4 1-1.8 2.5-2.3 1.5-.6 3.7-.6m210.3 0h5v15.8h-5q-2.4 0-4-.4-1.5-.5-2.2-2a13 13 0 0 1-.8-5.1q0-3.7.8-5.4 1-1.8 2.5-2.3 1.6-.6 3.7-.6M114.8 247v28.5h-10.9V257H91.6q-4.4 0-7.4 1.6-3 1.4-4.6 4.4t-1.6 7.2q0 4.3 1.6 7 1.5 2.9 4.6 4.3t7.4 1.4h51.7v-36h-8.8v28.5h-10.9V247Zm36.3 0v36h8.8v-36Zm39.7 0v35.8q0 1.5-.6 2.7t-2 2q-1.5.6-4 .7t-4.2-.7-2.4-2q-.9-1.3-.9-3.1l.2-2.8 1.5-10.8-8.7-1.1-1.2 8.4-.6 6.4q0 3.7 2 6.7a14 14 0 0 0 5.9 4.8q3.6 1.7 8.3 1.7 4.5 0 8-1.6 3.6-1.6 5.5-4.6 2-2.8 2-6.7V247Zm159.5 10a36 36 0 0 0-10 1.4 40 40 0 0 0-1.3 7.4 57 57 0 0 0 0 9.6h-11v-2a20 20 0 0 0-1.9-9.2q-1.8-3.6-5.4-5.3a20 20 0 0 0-8.7-1.8h-4.2v7.5h4.2q2.7 0 4.3.8 1.5.7 2.2 2.6.6 1.8.7 5.4v2h-12.7v7.6H434v-12.8q0-5-1.6-7.8-1.5-3-4.7-4.1-3.2-1.4-8-1.3a36 36 0 0 0-10 1.4 40 40 0 0 0-1.4 7.4 57 57 0 0 0 0 9.6h-10.9v-4.8q0-4.2-2-7.2t-5.5-4.6a18 18 0 0 0-7.9-1.7q-2.1 0-4.2.4l-4.3.8.7 7a48 48 0 0 1 6.7-.6q4 0 6 1.5 1.7 1.5 1.7 4.4v4.9h-23.9v-5.3q0-5-1.6-7.8-1.6-3-4.8-4.1-3-1.4-8-1.3m-131.7.1q-4.3 0-7.4 1.6-3 1.4-4.6 4.4t-1.6 7.2q0 4.3 1.6 7 1.6 2.9 4.6 4.3t7.4 1.4h3.5v1.6q0 2.3-1.5 3.4-1.4 1.2-4.7 1.2l-3-.2q-1.8 0-4.3-.4l-1.2 7a59 59 0 0 0 8.5 1q4.5 0 7.8-1.4 3.4-1.5 5.3-4.2a11 11 0 0 0 1.9-6.4V283h22.9a15 15 0 0 0 7.9-2q1 .6 2.2 1 2.3 1 4.7 1h13.9v-14l-.3-3.3-1.3-8.6-8.7 1.3a118 118 0 0 1 1.4 10.5v6.6h-5l-1.9-.4-.9-.5q.7-2.7.7-6.2v-8.6h-8.8v8.6q0 3-.4 4.6-.3 1.5-1 2a5 5 0 0 1-2.5.5h-3v-13h-9v13H231V257zm73.8 0v26.6q0 2.7-1 4-1 1.5-2.8 1.5h-2.8l-.2 7.3 3.1.2q3.8 0 6.6-1.7t4.3-4.6 1.6-6.7V257zm58 7.4q2.1 0 3.3.5t1.7 1.7q.4 1.3.4 3.4v5.4h-8a71 71 0 0 1 0-8.6l.2-2.3zm69.3 0q2.2 0 3.4.5t1.6 1.7q.5 1.3.5 3.4v5.4h-8a71 71 0 0 1-.1-8.6l.2-2.3zm-328.1.1H95v10.9h-3.4q-1.7 0-2.7-.3-1-.4-1.6-1.4a9 9 0 0 1-.5-3.5q0-2.6.6-3.7A3 3 0 0 1 89 265a8 8 0 0 1 2.5-.4m127 0h3.5v10.9h-3.5q-1.6 0-2.7-.3-1-.4-1.6-1.4a9 9 0 0 1-.5-3.5q0-2.6.6-3.7a3 3 0 0 1 1.7-1.6 8 8 0 0 1 2.5-.4\"/></g></svg>",
        "vn": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h512v512H0Z\"/><path fill=\"#ffda44\" d=\"m176 378 208-150H128l208 150-80-244Z\"/></g></svg>",
        "th": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h512v89l-79.2 163.7L512 423v89H0v-89l82.7-169.6L0 89z\"/><path fill=\"#eee\" d=\"M0 89h512v78l-42.6 91.2L512 345v78H0v-78l40-92.5L0 167z\"/><path fill=\"#0052b4\" d=\"M0 167h512v178H0z\"/></g></svg>",
        "id": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"m0 256 249.6-41.3L512 256v256H0z\"/><path fill=\"#d80027\" d=\"M0 0h512v256H0z\"/></g></svg>",
        "in": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"m0 160 256-32 256 32v192l-256 32L0 352z\"/><path fill=\"#ff9811\" d=\"M0 0h512v160H0Z\"/><path fill=\"#6da544\" d=\"M0 352h512v160H0Z\"/><circle cx=\"256\" cy=\"256\" r=\"72\" fill=\"#0052b4\"/><circle cx=\"256\" cy=\"256\" r=\"48\" fill=\"#eee\"/><circle cx=\"256\" cy=\"256\" r=\"24\" fill=\"#0052b4\"/></g></svg>",
        "tr": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h512v512H0z\"/><path fill=\"#eee\" d=\"M208 115a141 141 0 1 0 106 242q-25 13-54 13a114 114 0 1 1 54-215 141 141 0 0 0-106-40m142 67v56l-54 18 54 17v57l33-46 54 18-33-46 33-46-54 18z\"/></g></svg>",
        "nl": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z\"/><path fill=\"#a2001d\" d=\"M0 0h512v167H0z\"/><path fill=\"#0052b4\" d=\"M0 345h512v167H0z\"/></g></svg>",
        "pl": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"m0 256 256.4-44.3L512 256v256H0z\"/><path fill=\"#eee\" d=\"M0 0h512v256H0z\"/></g></svg>",
        "ua": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#ffda44\" d=\"m0 256 258-39.4L512 256v256H0z\"/><path fill=\"#338af3\" d=\"M0 0h512v256H0z\"/></g></svg>",
        "se": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#0052b4\" d=\"M0 0h133.6l35.3 16.7L200.3 0H512v222.6l-22.6 31.7 22.6 35.1V512H200.3l-32-19.8-34.7 19.8H0V289.4l22.1-33.3L0 222.6z\"/><path fill=\"#ffda44\" d=\"M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0z\"/></g></svg>",
        "dk": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h133.6l32.7 20.3 34-20.3H512v222.6L491.4 256l20.6 33.4V512H200.3l-31.7-20.4-35 20.4H0V289.4l29.4-33L0 222.7z\"/><path fill=\"#eee\" d=\"M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0h-66.7z\"/></g></svg>",
        "fi": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 0h133.6l35.3 16.7L200.3 0H512v222.6l-22.6 31.7 22.6 35.1V512H200.3l-32-19.8-34.7 19.8H0V289.4l22.1-33.3L0 222.6z\"/><path fill=\"#0052b4\" d=\"M133.6 0v222.6H0v66.8h133.6V512h66.7V289.4H512v-66.8H200.3V0h-66.7z\"/></g></svg>",
        "no": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#d80027\" d=\"M0 0h100.2l66.1 53.5L233.7 0H512v189.3L466.3 257l45.7 65.8V512H233.7l-68-50.7-65.5 50.7H0V322.8l51.4-68.5-51.4-65z\"/><path fill=\"#eee\" d=\"M100.2 0v189.3H0v33.4l24.6 33L0 289.5v33.4h100.2V512h33.4l30.6-26.3 36.1 26.3h33.4V322.8H512v-33.4l-24.6-33.7 24.6-33v-33.4H233.7V0h-33.4l-33.8 25.3L133.6 0z\"/><path fill=\"#0052b4\" d=\"M133.6 0v222.7H0v66.7h133.6V512h66.7V289.4H512v-66.7H200.3V0z\"/></g></svg>",
        "cz": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 0h512v256l-265 45.2z\"/><path fill=\"#d80027\" d=\"M210 256h302v256H0z\"/><path fill=\"#0052b4\" d=\"M0 0v512l256-256L0 0z\"/></g></svg>",
        "gr": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#0052b4\" d=\"M0 0h99l29 32 28-32h356v57l-32 28 32 29v57l-32 28 32 29v57l-32 28 32 28v57l-32 29 32 28v57H0v-57l32-28-32-29v-56l32-29-32-28V171l32-29-32-28Z\"/><path fill=\"#eee\" d=\"M99 0v114H0v57h99v114H0v57h512v-57H156V171h100v-57H156V0Zm157 57v57h256V57Zm0 114v57h256v-57ZM0 398v57h512v-57z\"/></g></svg>",
        "hu": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"m0 167 253.8-19.3L512 167v178l-254.9 32.3L0 345z\"/><path fill=\"#d80027\" d=\"M0 0h512v167H0z\"/><path fill=\"#6da544\" d=\"M0 345h512v167H0z\"/></g></svg>",
        "ro": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#ffda44\" d=\"M167 0h178l25.9 252.3L345 512H167l-29.8-253.4z\"/><path fill=\"#0052b4\" d=\"M0 0h167v512H0z\"/><path fill=\"#d80027\" d=\"M345 0h167v512H345z\"/></g></svg>",
        "my": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M256 0h256v64l-32 32 32 32v64l-32 32 32 32v64l-32 32 32 32v64l-256 32L0 448v-64l32-32-32-32v-64z\"/><path fill=\"#d80027\" d=\"M224 64h288v64H224Zm0 128h288v64H256ZM0 320h512v64H0Zm0 128h512v64H0Z\"/><path fill=\"#0052b4\" d=\"M0 0h256v256H0Z\"/><path fill=\"#ffda44\" d=\"M142 78a78 78 0 1 0 58 134 63 63 0 0 1-30 7 63 63 0 1 1 30-119 78 78 0 0 0-58-22m46 33-11 24-26-6 12 23-21 17 26 5v26l20-16 20 16v-26l26-5-21-17 12-23-26 6z\"/></g></svg>",
        "ph": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#0052b4\" d=\"M0 0h512v256l-265 45.2z\"/><path fill=\"#d80027\" d=\"M210 256h302v256H0z\"/><path fill=\"#eee\" d=\"M0 0v512l256-256z\"/><path fill=\"#ffda44\" d=\"M175.3 256 144 241.3l16.7-30.3-34 6.5-4.3-34.3-23.6 25.2L75 183.2l-4.3 34.3-34-6.5 16.7 30.3L22.3 256l31.2 14.7L37 301l34-6.5 4.2 34.3 23.7-25.2 23.6 25.2 4.3-34.3 34 6.5-16.7-30.3zm-107-155.8 10.4 14.5 17-5.4-10.6 14.4 10.4 14.5-17-5.6L68 147l.2-17.9-17-5.6 17-5.4zm0 264.8 10.4 14.6 17-5.4-10.6 14.3 10.4 14.6-17-5.7L68 411.8l.2-17.9-17-5.6 17-5.4zm148.4-132.4L206.3 247l-17-5.4 10.5 14.4-10.4 14.6 17-5.7 10.6 14.4-.1-17.9 17-5.6-17.1-5.4z\"/></g></svg>",
        "il": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 0h512v55.7l-25 32.7 25 34v267.2l-26 36 26 30.7V512H0v-55.7l24.8-34.1L0 389.6V122.4l27.2-33.2L0 55.7z\"/><path fill=\"#0052b4\" d=\"M0 55.7v66.7h512V55.7zm0 333.9v66.7h512v-66.7zm352.4-189.3H288l-32-55.6-32.1 55.6h-64.3l32.1 55.7-32 55.7h64.2l32.1 55.6 32.1-55.6h64.3L320.3 256l32-55.7zm-57 55.7-19.7 34.2h-39.4L216.5 256l19.8-34.2h39.4l19.8 34.2zM256 187.6l7.3 12.7h-14.6zm-59.2 34.2h14.7l-7.4 12.7zm0 68.4 7.3-12.7 7.4 12.7zm59.2 34.2-7.3-12.7h14.6zm59.2-34.2h-14.7l7.4-12.7zm-14.7-68.4h14.7l-7.3 12.7z\"/></g></svg>",
        "ir": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><mask id=\"a\"><circle cx=\"256\" cy=\"256\" r=\"256\" fill=\"#fff\"/></mask><g mask=\"url(#a)\"><path fill=\"#eee\" d=\"M0 144.7 258.8 39.6 512 144.7v222.6L257 493 0 367.3z\"/><path fill=\"#6da544\" d=\"M0 0v144.7h105.6v-22.2h33.6v22.2h33.3v-22.2h33.6v22.2h33.3v-22.2H273v22.2h33v-22.2h33.6v22.2h33.2v-22.2h33.6v22.2H512V0z\"/><path fill=\"#d80027\" d=\"M0 367.3V512h512V367.3H406.4v22.4h-33.6v-22.4h-33.2v22.4H306v-22.4h-33v22.4h-33.6v-22.4h-33.3v22.4h-33.6v-22.4h-33.3v22.4h-33.6v-22.4zm339.1-178h-33.4c.2 3.7.4 7.4.4 11.1 0 24.8-6.2 48.8-17 66-3.3 5.2-9 12.6-16.4 17.6v-94.7h-33.4v94.8c-7.5-5-13-12.4-16.4-17.7-10.8-17-17-41-17-65.9 0-3.7.2-7.4.4-11H173a190 190 0 0 0-.4 11c0 68.7 36.7 122.5 83.5 122.5s83.5-53.8 83.5-122.5c0-3.7-.1-7.4-.4-11z\"/></g></svg>",
    ]
}

/// 现代化国旗图像提供者，提供极速内存缓存与高保真矢量渲染
public final class CountryFlagProvider {
    public static let shared = CountryFlagProvider()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 120
    }

    /// 获取对应语言或国家的矢量国旗 NSImage
    public func flagImage(for languageOrCountryCode: String, targetSize: CGFloat = 48) -> NSImage? {
        let key = languageOrCountryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "\(key)_\(Int(targetSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // 查找映射表
        let resolvedCountry = CountryFlagAssets.languageToCountryCode[key] ??
            CountryFlagAssets.languageToCountryCode[key.lowercased()] ??
            CountryFlagAssets.languageToCountryCode[key.split(separator: "-").first.map(String.init) ?? key] ??
            key.lowercased()

        guard let svgString = CountryFlagAssets.svgs[resolvedCountry] ?? CountryFlagAssets.svgs[key.lowercased()],
              let data = svgString.data(using: .utf8),
              let image = NSImage(data: data) else {
            return nil
        }

        image.size = NSSize(width: targetSize, height: targetSize)
        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

/// 符合 Quiet Signal 视觉阶梯的高保真圆形国旗/标志视图
public struct CountryFlagView: View {
    public let code: String
    public var size: CGFloat = 20
    @Environment(\.colorScheme) private var colorScheme

    public init(code: String, size: CGFloat = 20) {
        self.code = code
        self.size = size
    }

    public var body: some View {
        Group {
            if code == "auto" {
                // 自动识别专属：精致全球多语言渐变圆标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.53, blue: 0.90),
                                    Color(red: 0.05, green: 0.38, blue: 0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: size * 0.62, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
            } else if let image = CountryFlagProvider.shared.flagImage(for: code, targetSize: size * 2) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // 回退到系统 Emoji 徽标或默认地球
                let fallback = SupportedLanguages.find(by: code)?.flag ?? "🌐"
                Text(fallback)
                    .font(.system(size: size * 0.76))
                    .frame(width: size, height: size)
            }
        }
        .overlay {
            Circle()
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.16)
                        : Color.black.opacity(0.10),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 1.5, x: 0, y: 0.8)
    }
}
