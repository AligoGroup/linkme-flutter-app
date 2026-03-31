/*
 * x265.h - H.265/HEVC encoder API
 * Copyright (C) 2013-2024 x265 project
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#ifndef X265_H
#define X265_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* x265 build version */
#define X265_BUILD 210
#define X265_VERSION "3.5"
#define X265_MAJOR_VERSION 3

/* x265 bit depth */
extern const int x265_max_bit_depth;
extern const char *x265_version_str;
extern const char *x265_build_info_str;

/* Encoder structures and types */
typedef struct x265_encoder x265_encoder;
typedef struct x265_param x265_param;
typedef struct x265_picture x265_picture;
typedef struct x265_analysis_data x265_analysis_data;
typedef struct x265_zone x265_zone;
typedef struct x265_stats x265_stats;
typedef struct x265_vmaf_data x265_vmaf_data;
typedef struct x265_vmaf_framedata x265_vmaf_framedata;
typedef struct x265_ctu_info_t x265_ctu_info_t;
typedef struct x265_picyuv x265_picyuv;
typedef struct x265_frame_stats x265_frame_stats;

/* NAL unit types */
typedef enum {
    NAL_UNIT_CODED_SLICE_TRAIL_N = 0,
    NAL_UNIT_CODED_SLICE_TRAIL_R,
    NAL_UNIT_CODED_SLICE_TSA_N,
    NAL_UNIT_CODED_SLICE_TSA_R,
    NAL_UNIT_CODED_SLICE_STSA_N,
    NAL_UNIT_CODED_SLICE_STSA_R,
    NAL_UNIT_CODED_SLICE_RADL_N,
    NAL_UNIT_CODED_SLICE_RADL_R,
    NAL_UNIT_CODED_SLICE_RASL_N,
    NAL_UNIT_CODED_SLICE_RASL_R,
    NAL_UNIT_CODED_SLICE_BLA_W_LP = 16,
    NAL_UNIT_CODED_SLICE_BLA_W_RADL,
    NAL_UNIT_CODED_SLICE_BLA_N_LP,
    NAL_UNIT_CODED_SLICE_IDR_W_RADL,
    NAL_UNIT_CODED_SLICE_IDR_N_LP,
    NAL_UNIT_CODED_SLICE_CRA,
    NAL_UNIT_VPS = 32,
    NAL_UNIT_SPS,
    NAL_UNIT_PPS,
    NAL_UNIT_ACCESS_UNIT_DELIMITER,
    NAL_UNIT_EOS,
    NAL_UNIT_EOB,
    NAL_UNIT_FILLER_DATA,
    NAL_UNIT_PREFIX_SEI,
    NAL_UNIT_SUFFIX_SEI,
    NAL_UNIT_UNSPECIFIED = 62,
    NAL_UNIT_INVALID = 64
} NalUnitType;

/* Slice types */
typedef enum {
    X265_TYPE_AUTO = 0x0000,
    X265_TYPE_IDR  = 0x0001,
    X265_TYPE_I    = 0x0002,
    X265_TYPE_P    = 0x0003,
    X265_TYPE_BREF = 0x0004,
    X265_TYPE_B    = 0x0005,
    X265_TYPE_KEYFRAME = 0x0006
} X265_SliceType;

/* Color space */
typedef enum {
    X265_CSP_I400 = 0,
    X265_CSP_I420 = 1,
    X265_CSP_I422 = 2,
    X265_CSP_I444 = 3,
    X265_CSP_COUNT = 4
} X265_ColorSpace;

/* Rate control modes */
typedef enum {
    X265_RC_CQP = 0,
    X265_RC_CRF = 1,
    X265_RC_ABR = 2
} X265_RateControlMode;

/* NAL structure */
typedef struct x265_nal {
    uint32_t type;
    uint32_t sizeBytes;
    uint8_t* payload;
} x265_nal;

/* Rate control parameters */
typedef struct {
    int rateControlMode;
    int qp;
    int bitrate;
    double rateTolerance;
    double qCompress;
    double ipFactor;
    double pbFactor;
    int qpStep;
    int qpMin;
    int qpMax;
    int aqMode;
    double aqStrength;
    int vbvMaxBitrate;
    int vbvBufferSize;
    double vbvBufferInit;
    int cuTree;
    double rfConstant;
    int rfConstantMax;
    int rfConstantMin;
} x265_rc_t;

/* Main parameter structure */
struct x265_param {
    /* Source properties */
    int sourceWidth;
    int sourceHeight;
    int internalCsp;
    int levelIdc;
    int bHighTier;
    int interlaceMode;
    
    /* Coding structure */
    int keyframeMax;
    int keyframeMin;
    int bframes;
    int bFrameAdaptive;
    int bBPyramid;
    int bOpenGOP;
    int scenecutThreshold;
    int lookaheadDepth;
    int radl;
    
    /* Frame rate */
    uint32_t fpsNum;
    uint32_t fpsDenom;
    
    /* Rate control */
    x265_rc_t rc;
    
    /* Quality/Speed tradeoff */
    int maxNumReferences;
    int bEnableRectInter;
    int bEnableAMP;
    int maxTUSize;
    int tuQTMaxInterDepth;
    int tuQTMaxIntraDepth;
    int limitReferences;
    
    /* Coding tools */
    int bEnableStrongIntraSmoothing;
    int bEnableConstrainedIntra;
    int bEnableLoopFilter;
    int bEnableSAO;
    int bEnableSignHiding;
    int bEnableTransformSkip;
    int bEnableTSkipFast;
    int bEnableWeightedPred;
    int bEnableWeightedBiPred;
    
    /* Temporal / motion search options */
    int searchMethod;
    int subpelRefine;
    int searchRange;
    int maxNumMergeCand;
    int bEnableTemporalMvp;
    int bEnableEarlySkip;
    int bEnableFastIntra;
    int bEnableCbfFastMode;
    
    /* Analysis options */
    int rdLevel;
    int rdoqLevel;
    int bEnableRdRefine;
    int psyRd;
    double psyRdoq;
    int analysisReuseMode;
    const char* analysisReuseFileName;
    
    /* Slice decision options */
    int bIntraRefresh;
    int decodingRefreshType;
    
    /* Output options */
    int bRepeatHeaders;
    int bAnnexB;
    int bEnableAccessUnitDelimiters;
    int bEmitHRDSEI;
    int bEmitInfoSEI;
    int bEmitHDRSEI;
    
    /* Threading options */
    int poolNumThreads;
    int frameNumThreads;
    int bEnableWavefront;
    
    /* VUI parameters */
    struct {
        int bEnableVideoSignalTypePresentFlag;
        int bEnableVideoFullRangeFlag;
        int bEnableColorDescriptionPresentFlag;
        int colorPrimaries;
        int transferCharacteristics;
        int matrixCoeffs;
        int bEnableChromaLocInfoPresentFlag;
        int chromaSampleLocTypeTopField;
        int chromaSampleLocTypeBottomField;
    } vui;
    
    /* Additional parameters */
    const char* logLevel;
    void* logContext;
};

/* Picture structure */
struct x265_picture {
    /* Input properties */
    void* planes[3];
    int stride[3];
    int bitDepth;
    int colorSpace;
    
    /* Output properties */
    int sliceType;
    int64_t pts;
    int64_t dts;
    void* userData;
    
    /* Force picture parameters */
    int forceqp;
    
    /* Analysis data */
    x265_analysis_data* analysisData;
    
    /* Quantization offsets */
    double* quantOffsets;
    
    /* Picture timing SEI */
    uint32_t picStruct;
};

/* API structure for multi-library interface */
typedef struct x265_api {
    /* API version */
    int api_major_version;
    int api_minor_version;
    int sizeof_param;
    int sizeof_picture;
    int sizeof_analysis_data;
    int sizeof_zone;
    int sizeof_stats;
    
    /* Build info */
    int bit_depth;
    const char* version_str;
    const char* build_info_str;
    
    /* Encoder functions */
    x265_param* (*param_alloc)(void);
    void (*param_free)(x265_param*);
    int (*param_default_preset)(x265_param*, const char* preset, const char* tune);
    int (*param_apply_profile)(x265_param*, const char* profile);
    int (*param_parse)(x265_param*, const char* name, const char* value);
    
    x265_picture* (*picture_alloc)(void);
    void (*picture_free)(x265_picture*);
    void (*picture_init)(x265_param*, x265_picture*);
    
    x265_encoder* (*encoder_open)(x265_param*);
    void (*encoder_parameters)(x265_encoder*, x265_param*);
    int (*encoder_reconfig)(x265_encoder*, x265_param*);
    int (*encoder_headers)(x265_encoder*, x265_nal**, uint32_t*);
    int (*encoder_encode)(x265_encoder*, x265_nal**, uint32_t*, x265_picture*, x265_picture*);
    void (*encoder_get_stats)(x265_encoder*, x265_stats*, uint32_t);
    void (*encoder_log)(x265_encoder*, int, char**);
    void (*encoder_close)(x265_encoder*);
    void (*cleanup)(void);
    
    /* Analysis functions */
    int (*alloc_analysis_data)(x265_picture*);
    void (*free_analysis_data)(x265_picture*);
    
    /* VMAF functions */
    double (*calculate_vmafscore)(x265_param*, x265_vmaf_data*);
    double (*calculate_vmaf_framelevelscore)(x265_vmaf_framedata*);
} x265_api;

/* Preset and tune names */
extern const char* const x265_preset_names[];
extern const char* const x265_tune_names[];
extern const char* const x265_profile_names[];

/* Parameter functions */
x265_param* x265_param_alloc(void);
void x265_param_free(x265_param*);
int x265_param_default_preset(x265_param*, const char* preset, const char* tune);
int x265_param_apply_profile(x265_param*, const char* profile);
void x265_param_default(x265_param*);

#define X265_PARAM_BAD_NAME  (-1)
#define X265_PARAM_BAD_VALUE (-2)
int x265_param_parse(x265_param*, const char* name, const char* value);

/* Picture functions */
x265_picture* x265_picture_alloc(void);
void x265_picture_free(x265_picture*);
void x265_picture_init(x265_param*, x265_picture*);

/* Encoder functions */
x265_encoder* x265_encoder_open(x265_param*);
void x265_encoder_parameters(x265_encoder*, x265_param*);
int x265_encoder_reconfig(x265_encoder*, x265_param*);
int x265_encoder_reconfig_zone(x265_encoder*, x265_param*);
int x265_encoder_headers(x265_encoder*, x265_nal**, uint32_t*);
int x265_encoder_encode(x265_encoder*, x265_nal**, uint32_t*, x265_picture* pic_in, x265_picture* pic_out);
void x265_encoder_get_stats(x265_encoder*, x265_stats*, uint32_t);
void x265_encoder_log(x265_encoder*, int, char**);
void x265_encoder_close(x265_encoder*);
void x265_cleanup(void);

/* Analysis functions */
int x265_alloc_analysis_data(x265_picture*);
void x265_free_analysis_data(x265_picture*);
int x265_set_analysis_data(x265_encoder*, x265_analysis_data*, int, uint32_t);

/* Multi-library interface */
const x265_api* x265_api_get(int bitDepth);
const x265_api* x265_api_query(int bitDepth, int apiVersion, int* err);

/* Utility functions */
int x265_get_slicetype_poc_and_scenecut(x265_encoder*, int* slicetype, int* poc, int* sceneCut);
int x265_get_ref_frame_list(x265_encoder*, x265_picyuv**, x265_picyuv**, int, int, int*, int*);
int x265_encoder_ctu_info(x265_encoder*, int, x265_ctu_info_t**);

/* VMAF functions */
double x265_calculate_vmafscore(x265_param*, x265_vmaf_data*);
double x265_calculate_vmaf_framelevelscore(x265_vmaf_framedata*);

#ifdef __cplusplus
}
#endif

#endif /* X265_H */
