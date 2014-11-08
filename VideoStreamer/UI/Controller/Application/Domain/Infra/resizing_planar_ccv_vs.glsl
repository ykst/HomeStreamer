// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
attribute vec4 position;
attribute vec4 input_texture_coordinate1;
attribute vec4 input_texture_coordinate2;
attribute vec4 input_texture_coordinate3;
attribute vec4 input_texture_coordinate4;

varying vec2 texture_coordinate1;
varying vec2 texture_coordinate2;
varying vec2 texture_coordinate3;
varying vec2 texture_coordinate4;

void main()
{
    gl_Position = position;
    texture_coordinate1 = input_texture_coordinate1.xy;
    texture_coordinate2 = input_texture_coordinate2.xy;
    texture_coordinate3 = input_texture_coordinate3.xy;
    texture_coordinate4 = input_texture_coordinate4.xy;
}
