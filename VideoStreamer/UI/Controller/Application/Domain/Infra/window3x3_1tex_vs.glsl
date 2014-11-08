// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
attribute vec4 position;
attribute vec4 inputTextureCoordinate;

varying vec2 left_tc;
varying vec2 left_top_tc;
varying vec2 left_bottom_tc;
varying vec2 center_top_tc;
varying vec2 center_tc;
varying vec2 center_bottom_tc;
varying vec2 right_top_tc;
varying vec2 right_tc;
varying vec2 right_bottom_tc;

const highp vec2 xstep = vec2(1.0/640.0, 0); // TODO: variable size
const highp vec2 ystep = vec2(0, 1.0/640.0); // TODO: variable size

void main()
{
    gl_Position = position;
    left_tc = inputTextureCoordinate.xy - xstep;
    left_top_tc = inputTextureCoordinate.xy - xstep - ystep;
    left_bottom_tc = inputTextureCoordinate.xy - xstep + ystep;
    center_tc = inputTextureCoordinate.xy;
    center_top_tc = inputTextureCoordinate.xy - ystep;
    center_bottom_tc = inputTextureCoordinate.xy + ystep;
    right_tc = inputTextureCoordinate.xy + xstep;
    right_top_tc = inputTextureCoordinate.xy + xstep - ystep;
    right_bottom_tc = inputTextureCoordinate.xy + xstep + ystep;
}

