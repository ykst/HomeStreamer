// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
varying highp vec2 texture_coordinate1;
varying highp vec2 texture_coordinate2;
varying highp vec2 texture_coordinate3;
varying highp vec2 texture_coordinate4;
uniform sampler2D source_tex;
uniform sampler2D lut_tex;
uniform mediump int mode;

void main()
{
    mediump vec2 coord1 = texture_coordinate1;
    mediump vec2 coord2 = texture_coordinate2;
    mediump vec2 coord3 = texture_coordinate3;
    mediump vec2 coord4 = texture_coordinate4;

    if (mode == 0) { // Y planar passthrough 4-packed, with LUT
        gl_FragColor = vec4(texture2D(lut_tex, vec2(texture2D(source_tex, coord1).r, 0.5)).r,
                            texture2D(lut_tex, vec2(texture2D(source_tex, coord2).r, 0.5)).r,
                            texture2D(lut_tex, vec2(texture2D(source_tex, coord3).r, 0.5)).r,
                            texture2D(lut_tex, vec2(texture2D(source_tex, coord4).r, 0.5)).r);
    } else if (mode == 1) { // Y planaer passthrough 4-packed
        gl_FragColor = vec4(texture2D(source_tex, coord1).r,
                            texture2D(source_tex, coord2).r,
                            texture2D(source_tex, coord3).r,
                            texture2D(source_tex, coord4).r);
    } else if (mode == 2) { // U planar
        gl_FragColor = vec4(texture2D(source_tex, coord1).r,
                            texture2D(source_tex, coord2).r,
                            texture2D(source_tex, coord3).r,
                            texture2D(source_tex, coord4).r);

    } else if (mode == 3) { // V planar
        gl_FragColor = vec4(texture2D(source_tex, coord1).a,
                            texture2D(source_tex, coord2).a,
                            texture2D(source_tex, coord3).a,
                            texture2D(source_tex, coord4).a);
    }
}
