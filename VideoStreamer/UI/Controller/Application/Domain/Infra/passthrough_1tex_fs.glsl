// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
varying highp vec2 textureCoordinate;

uniform sampler2D inputTexture;

void main()
{
    gl_FragColor = texture2D(inputTexture, textureCoordinate);
}