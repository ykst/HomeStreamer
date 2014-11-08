// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
varying highp vec2 textureCoordinate;

uniform sampler2D luminanceTexture;
uniform sampler2D chrominanceTexture;
uniform mediump mat3 colorConversionMatrix;
uniform sampler2D luminance_lut_tex;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;

    yuv.x = texture2D(luminance_lut_tex, vec2(texture2D(luminanceTexture, textureCoordinate).r, 0.5)).r;
    yuv.yz = texture2D(chrominanceTexture, textureCoordinate).ra - vec2(0.5, 0.5);
    rgb = colorConversionMatrix * yuv;

    gl_FragColor = vec4(rgb, 1);
}

