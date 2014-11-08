// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
attribute vec4 position;
attribute vec4 inputTextureCoordinate;

uniform highp mat3 affine_mat;

varying vec2 textureCoordinate;

void main()
{
    gl_Position = position;
    textureCoordinate = (vec3(inputTextureCoordinate.xy, 1) * affine_mat).xy;
}

