// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
uniform sampler2D iframe_tex;
uniform sampler2D pframe_tex;

varying highp vec2 textureCoordinate;

void main()
{
    mediump vec4 iframe_color = texture2D(iframe_tex, textureCoordinate);
    mediump vec4 pframe_color = texture2D(pframe_tex, textureCoordinate);

    gl_FragColor = (iframe_color - pframe_color) / 2.0 + vec4(0.5, 0.5, 0.5, 0.5);
}
