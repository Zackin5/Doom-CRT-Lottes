//
// PUBLIC DOMAIN CRT STYLED SCAN-LINE SHADER
//
//   by Timothy Lottes
//
// This is more along the style of a really good CGA arcade monitor.
// With RGB inputs instead of NTSC.
// The shadow mask example has the mask rotated 90 degrees for less chromatic aberration.
//
// Left it unoptimized to show the theory behind the algorithm.
//
// It is an example what I personally would want as a display option for pixel art games.
// Please take and use, change, or whatever.
//
// Ported to GZDoom by Zackin5
// Additional tweaks taken from RSRetroArch repo
//

//------------------------------------------------------------------------

// sRGB to Linear.
// Assuing using sRGB typed textures this should not be needed.
float ToLinear1(float c)
{
   return scaleInLinearGamma==0 ? c : (c<=0.04045)?c/12.92:pow((c+0.055)/1.055,2.4);
}
vec3 ToLinear(vec3 c)
{
   return scaleInLinearGamma==0 ? c : vec3(ToLinear1(c.r),ToLinear1(c.g),ToLinear1(c.b));
}

// Linear to sRGB.
// Assuming using sRGB typed textures this should not be needed.
float ToSrgb1(float c)
{
   return scaleInLinearGamma==0 ? c : (c<0.0031308?c*12.92:1.055*pow(c,0.41666)-0.055);
}

vec3 ToSrgb(vec3 c)
{
    return scaleInLinearGamma==0 ? c : vec3(ToSrgb1(c.r),ToSrgb1(c.g),ToSrgb1(c.b));
}

// Nearest emulated sample given floating point position and texel offset.
// Also zero's off screen.
vec3 Fetch(vec2 pos, vec2 off, vec2 texture_size){
    pos=(floor(pos*texture_size.xy+off)+vec2(0.5,0.5))/texture_size.xy;
    if(max(abs(pos.x-0.5),abs(pos.y-0.5))>0.5)return vec3(0.0,0.0,0.0);
    return ToLinear(brightboost * texture(InputTexture,pos.xy).rgb);
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos, vec2 texture_size){
  pos=pos*texture_size.xy;
  return -((pos-floor(pos))-vec2(0.5, 0.5));
}

// 1D Gaussian.
float Gaus(float pos,float scale){
  return exp2(scale*pow(abs(pos),shape));
}

// 3-tap Gaussian filter along horz line.
vec3 Horz3(vec2 pos, float off, vec2 texture_size){
  vec3 b=Fetch(pos,vec2(-1.0,off),texture_size);
  vec3 c=Fetch(pos,vec2( 0.0,off),texture_size);
  vec3 d=Fetch(pos,vec2( 1.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardPix;
  float wb=Gaus(dst-1.0,scale);
  float wc=Gaus(dst+0.0,scale);
  float wd=Gaus(dst+1.0,scale);
  // Return filtered sample.
  return (b*wb+c*wc+d*wd)/(wb+wc+wd);}
  
// 5-tap Gaussian filter along horz line.
vec3 Horz5(vec2 pos, float off, vec2 texture_size){
  vec3 a=Fetch(pos,vec2(-2.0,off),texture_size);
  vec3 b=Fetch(pos,vec2(-1.0,off),texture_size);
  vec3 c=Fetch(pos,vec2( 0.0,off),texture_size);
  vec3 d=Fetch(pos,vec2( 1.0,off),texture_size);
  vec3 e=Fetch(pos,vec2( 2.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardPix;
  float wa=Gaus(dst-2.0,scale);
  float wb=Gaus(dst-1.0,scale);
  float wc=Gaus(dst+0.0,scale);
  float wd=Gaus(dst+1.0,scale);
  float we=Gaus(dst+2.0,scale);
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we)/(wa+wb+wc+wd+we);}

// 7-tap Gaussian filter along horz line.
vec3 Horz7(vec2 pos, float off, vec2 texture_size){
  vec3 a=Fetch(pos,vec2(-3.0,off),texture_size);
  vec3 b=Fetch(pos,vec2(-2.0,off),texture_size);
  vec3 c=Fetch(pos,vec2(-1.0,off),texture_size);
  vec3 d=Fetch(pos,vec2( 0.0,off),texture_size);
  vec3 e=Fetch(pos,vec2( 1.0,off),texture_size);
  vec3 f=Fetch(pos,vec2( 2.0,off),texture_size);
  vec3 g=Fetch(pos,vec2( 3.0,off),texture_size);
  float dst=Dist(pos, texture_size).x;
  // Convert distance to weight.
  float scale=hardBloomPix;
  float wa=Gaus(dst-3.0,scale);
  float wb=Gaus(dst-2.0,scale);
  float wc=Gaus(dst-1.0,scale);
  float wd=Gaus(dst+0.0,scale);
  float we=Gaus(dst+1.0,scale);
  float wf=Gaus(dst+2.0,scale);
  float wg=Gaus(dst+3.0,scale);
  // Return filtered sample.
  return (a*wa+b*wb+c*wc+d*wd+e*we+f*wf+g*wg)/(wa+wb+wc+wd+we+wf+wg);}

// Return scanline weight.
float Scan(vec2 pos,float off, vec2 texture_size){
  float dst=Dist(pos, texture_size).y;
  return Gaus(dst+off,hardScan);
}
 
  // Return scanline weight for bloom.
float BloomScan(vec2 pos,float off, vec2 texture_size){
  float dst=Dist(pos, texture_size).y;
  return Gaus(dst+off,hardBloomScan);
}

// Allow nearest three lines to effect pixel.
vec3 Tri(vec2 posWarped, vec2 pos, vec2 texture_size){
  vec3 a=Horz3(posWarped,-1.0, texture_size);
  vec3 b=Horz5(posWarped, 0.0, texture_size);
  vec3 c=Horz3(posWarped, 1.0, texture_size);
  float wa=Scan(pos,-1.0, texture_size);
  float wb=Scan(pos, 0.0, texture_size);
  float wc=Scan(pos, 1.0, texture_size);
  return a*wa+b*wb+c*wc;
  // return vec3(wa, wb, wc);
  // return vec3(wa, 0, 0);
}

// Small bloom.
vec3 Bloom(vec2 posWarped, vec2 pos, vec2 texture_size){
  vec3 a=Horz5(posWarped,-2.0, texture_size);
  vec3 b=Horz7(posWarped,-1.0, texture_size);
  vec3 c=Horz7(posWarped, 0.0, texture_size);
  vec3 d=Horz7(posWarped, 1.0, texture_size);
  vec3 e=Horz5(posWarped, 2.0, texture_size);
  float wa=BloomScan(pos,-2.0, texture_size);
  float wb=BloomScan(pos,-1.0, texture_size);
  float wc=BloomScan(pos, 0.0, texture_size);
  float wd=BloomScan(pos, 1.0, texture_size);
  float we=BloomScan(pos, 2.0, texture_size);
  return a*wa+b*wb+c*wc+d*wd+e*we;
}

// Distortion of scanlines, and end of screen alpha.
vec2 Warp(vec2 pos){
  pos=pos*2.0-1.0;
  pos*=vec2(1.0+(pos.y*pos.y)*warp_x, 1.0+(pos.x*pos.x)*warp_y);

  return pos*0.5+0.5;
}

// Shadow mask 
vec3 Mask(vec2 pos){
  vec3 mask=vec3(maskDark);

  vec2 mask_pos = maskRotate == 1 ? vec2(pos.y, pos.x) : pos;

  // Very compressed TV style shadow mask.
  if (shadowMask == 1) {
    float mask_line = maskLight;
    float odd=0.0;
    if(fract(mask_pos.x/6.0)<0.5) odd = 1.0;
    if(fract((mask_pos.y+odd)/2.0)<0.5) mask_line = maskDark;  
    mask_pos.x=fract(mask_pos.x/3.0);
   
    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
    mask *= mask_line;  
  } 

  // Aperture-grille.
  else if (shadowMask == 2) {
    mask_pos.x=fract(mask_pos.x/3.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  } 

  // Stretched VGA style shadow mask (same as prior shaders).
  else if (shadowMask == 3) {
    mask_pos.x+=mask_pos.y*3.0;
    mask_pos.x=fract(mask_pos.x/6.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  // VGA style shadow mask.
  else if (shadowMask == 4) {
    mask_pos.xy=floor(mask_pos.xy*vec2(1.0,0.5));
    mask_pos.x+=mask_pos.y*3.0;
    mask_pos.x=fract(mask_pos.x/6.0);

    if(mask_pos.x<0.333)mask.r=maskLight;
    else if(mask_pos.x<0.666)mask.g=maskLight;
    else mask.b=maskLight;
  }

  return mask;
}

void main()
{
    vec2 videoRes = textureSize( InputTexture, 0 );
    vec2 downsizedRes = (videoRes / downsizeMultiplier);
    vec2 pos = TexCoord.xy*(downsizedRes/videoRes)*(videoRes/downsizedRes);
    vec2 posWarped = Warp(TexCoord.xy*(downsizedRes/videoRes)*(videoRes/downsizedRes));
    vec3 outColor = Tri(posWarped, pos, downsizedRes);

    if(DO_BLOOM == 1)
        //Add Bloom
        outColor.rgb+=Bloom(posWarped, pos, downsizedRes)*bloomAmount;

    if(shadowMask > 0){
        vec2 maskRes = maskUseDownscale == 1 ? downsizedRes : videoRes;
        outColor.rgb*=Mask(floor(TexCoord*maskRes)+vec2(0.5,0.5));
    }

    FragColor = vec4(ToSrgb(outColor.rgb),1.0);
}