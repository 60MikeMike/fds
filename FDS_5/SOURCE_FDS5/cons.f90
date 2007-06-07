MODULE GLOBAL_CONSTANTS
 
! Module containing global constants, parameters, variables
 
USE PRECISION_PARAMETERS
IMPLICIT NONE

CHARACTER(255), PARAMETER :: consid='$Id$'

!Error code

INTEGER :: STOP_CODE=0
 
! Indices for various modes of operation

INTEGER, PARAMETER :: MIXTURE_FRACTION_SPECIES=1,GAS_SPECIES=2,AEROSOL_SPECIES=3            ! For SPECIES%MODE
INTEGER, PARAMETER :: MIXTURE_FRACTION_REACTION=1,FINITE_RATE_REACTION=2                    ! For REACTION%MODE
INTEGER, PARAMETER :: ADIABATIC_INDEX=0,INTERPOLATED_BC=6,SPECIFIED_TEMPERATURE=1, &
                      SPECIFIED_HEAT_FLUX=-1,THERMALLY_THICK=3,ZERO_GRADIENT=4   ! Heat transfer BC
INTEGER, PARAMETER :: EXPOSED=0,VOID=1,INSULATED=2                               ! Surface backing
INTEGER, PARAMETER :: SURF_CARTESIAN=0,SURF_CYLINDRICAL=1 ! Surface geometry
INTEGER, PARAMETER :: NO_MASS_FLUX=1,SPECIFIED_MASS_FRACTION=2,SPECIFIED_MASS_FLUX=3        ! Mass transfer BC
INTEGER, PARAMETER :: NULL_BOUNDARY=0,SOLID_BOUNDARY=1,OPEN_BOUNDARY=2,MIRROR_BOUNDARY=3, &
                      POROUS_BOUNDARY=4,INTERPOLATED_BOUNDARY=6
INTEGER, PARAMETER :: FUEL_INDEX=1,O2_INDEX=2,N2_INDEX=3,H2O_INDEX=4,CO2_INDEX=5,CO_INDEX=6,H2_INDEX=7, &
                      SOOT_INDEX=8,OTHER_INDEX=9                                            ! Mixture Fraction Species
INTEGER, PARAMETER :: DIRICHLET=1,NEUMANN=2                                                 ! Pressure Boundary Conditions
INTEGER, PARAMETER :: PYROLYSIS_NONE=0,PYROLYSIS_SOLID=1,PYROLYSIS_LIQUID=2,&
                      PYROLYSIS_MATERIAL=3,PYROLYSIS_SPECIFIED=4                            ! Pyrolysis model
INTEGER, PARAMETER :: ATMOSPHERIC=1, PARABOLIC=2, ONED_PARABOLIC=3                            ! Surface velocity profile
INTEGER, PARAMETER :: CELL_CENTER=1, CELL_FACE=2, CELL_EDGE=3                            ! Cell position for output quantities

! Miscellaneous logical constants
 
LOGICAL :: LES,DNS,ISOTHERMAL,RADIATION, &
         CYLINDRICAL,NOISE,MIXTURE_FRACTION=.FALSE., &
         BAROCLINIC,PREDICTOR,CORRECTOR, &
         APPEND,DROPLET_FILE,RESTART, &
         SUPPRESSION,CO_PRODUCTION,ACCUMULATE_WATER,WRITE_XYZ, &
         CHECK_POISSON,TWO_D,SET_UP,SMOKE3D, &
         WATER_EVAPORATION,FUEL_EVAPORATION, &
         EVAPORATION,DEBUG,SYNCHRONIZE,TIMING, &
         FLUSH_FILE_BUFFERS,PRESSURE_CORRECTION, &
         COLUMN_DUMP_LIMIT,MASS_FILE,STRATIFICATION,SOLID_PHASE_ONLY
LOGICAL, ALLOCATABLE, DIMENSION(:) :: SYNC_TIME_STEP,CHANGE_TIME_STEP,INTERPOLATED

! Miscellaneous character strings

CHARACTER(10) :: SMOKE3D_COMPRESSION
CHARACTER(50), DIMENSION(3,100) :: SMOKE3D_FILE
CHARACTER(256) :: TITLE,RENDER_FILE,INPUT_FILE='null'
CHARACTER(40) :: CHID,RESTART_CHID
CHARACTER(20) :: COMPILE_DATE,VERSION_STRING
 
! Global EVACuation parameters
LOGICAL, ALLOCATABLE, DIMENSION(:) :: EVACUATION_ONLY, EVACUATION_GRID
REAL(EB) :: EVAC_DT_FLOWFIELD,EVAC_DT_STEADY_STATE,EVAC_DT,T_EVAC,T_EVAC_SAVE
INTEGER :: EVAC_PRESSURE_ITERATIONS,EVAC_TIME_ITERATIONS,EVAC_N_QUANTITIES,I_EVAC
CHARACTER(30), ALLOCATABLE, DIMENSION(:) :: EVAC_CLASS_NAME
INTEGER, ALLOCATABLE, DIMENSION(:) :: EVAC_QUANTITIES_INDEX
INTEGER, ALLOCATABLE, DIMENSION(:,:) :: EVAC_CLASS_RGB

! Miscellaneous real constants
 
REAL(EB) :: T_BEGIN,T_END,RELAXATION_FACTOR, &
   CPOPR,RSC,RPR,TMPA,TMPA4,TMPM,RHOA,P_INF,P_STP,GRAV,R0,R1, &
   CP_GAMMA,GAMMA,U0,V0,W0,H0,GVEC(3),CSMAG, &
   LAPSE_RATE,ONTH,THFO,ONSI,HCH,HCV,TEX_ORI(3), &
   SIGMA,TWTH,FOTH,KAPPA0,C_FORCED,H_FIXED,ASSUMED_GAS_TEMPERATURE, &
   CHARACTERISTIC_VELOCITY,CFL_MAX,CFL_MIN,VN_MAX,VN_MIN,  &
   PI,RPI,RFPI,TWOPI,PIO2,PR,SC,C_P_W,H_V_W
REAL(FB) :: VERSION_NUMBER
 
! Combustion parameters
 
REAL(EB), PARAMETER :: MW_O2=32._EB,MW_H2=2._EB,MW_CO2=44._EB,MW_H2O=18._EB,MW_N2=28._EB,MW_CO=28._EB, &
                       MW_C=12._EB,MW_H=1_EB,MW_O=16._EB,MW_N=14._EB, &
                       !HEAT_OF_FORMATION kJ/mol Drysdale, Fire Dynamics
                       CO_HEAT_OF_FORMATION = 110.523E3_EB, CO2_HEAT_OF_FORMATION = 393.513E3_EB, &
                       H2O_HEAT_OF_FORMATION = 241.826E3_EB 
REAL(EB) :: MW_AIR,MW_SOOT,HRRPUA_SHEET,RHO_SOOT,VISIBILITY_FACTOR,MASS_EXTINCTION_COEFFICIENT,EC_LL
INTEGER :: N_SPECIES,N_SPEC_DILUENTS,I_WATER,I_CO2,N_REACTIONS,I_FUEL,I_PROG_CO, I_PROG_F, I_CO, I_O2,I_SOOT
REAL(EB) :: RSUM0
REAL(EB), DIMENSION(0:10) :: RCON_MF
REAL(EB), DIMENSION(0:10000) :: Z_2_MAX,MW_MF_CORR_O2,MW_MF_CORR_FUEL
REAL(EB), DIMENSION(0:10000,1:9) :: Y_CORR_O2,Y_CORR_FUEL

! Surface parameters

INTEGER, PARAMETER :: MAX_LAYERS=20, MAX_MATERIALS=20, MAX_MATERIALS_TOTAL=400, MAX_REACTIONS=10, MAX_STEPS=20

! Ramping parameters
 
CHARACTER(30) :: RAMP_ID(1000),RAMP_TYPE(1000)
INTEGER :: I_RAMP_GX,I_RAMP_GY,I_RAMP_GZ,N_RAMP
INTEGER, PARAMETER :: TIME_HEAT=-1,TIME_VELO=-2,TIME_TEMP=-3,TANH_RAMP=-2,TSQR_RAMP=-1

! TABLe parameters
CHARACTER(30) :: TABLE_ID(1000)
INTEGER :: N_TABLE=0,TABLE_TYPE(1000)
INTEGER, PARAMETER :: SPRAY_PATTERN=1

 
! Miscellaneous integer constants
 
INTEGER :: NMESHES=1
INTEGER :: ICYC,WALL_INCREMENT,NFRAMES,NCGC
INTEGER, ALLOCATABLE, DIMENSION(:,:) :: PBC
 
! Clocks for output file dumps
 
REAL(EB), ALLOCATABLE, DIMENSION(:) :: PART_CLOCK,CORE_CLOCK,SLCF_CLOCK, &
                                       PL3D_CLOCK,BNDF_CLOCK,ISOF_CLOCK,PROF_CLOCK
REAL(EB) :: MINT_CLOCK,DEVC_CLOCK,HRR_CLOCK,EVAC_CLOCK,CTRL_CLOCK
REAL(EB) :: DT_SLCF,DT_BNDF,DT_DEVC,DT_PL3D,DT_PART,DT_RESTART,DT_ISOF,DT_HRR,DT_MASS,DT_PROF,DT_CTRL
 
! Logical units for output files
 
INTEGER :: LU_PROF,LU_SLCF,LU_BNDF,LU_MASS,LU_HRR,LU_XYZ,LU_DEVC,LU_STATE,LU_CTRL
INTEGER, PARAMETER :: LU0=0,LU2=2,LU4=4,LU5=55,LU6=6, &
  LU11=11,LU12=12,LU13=13,LU14=14,LU15=15,LU16=16,LU18=18, &
  LU19=19,LU80=80,LU90=90,LU91=91,LU111=111,LU121_EVAC=121, &
  LU122_EVAC=122,LU123_EVAC=123
 
! Boundary condition arrays
 
CHARACTER(30) :: SURF_NAME(0:1000),MATL_NAME(1:1000)
INTEGER :: N_SURF,N_MATL,MIRROR_SURF_INDEX,OPEN_SURF_INDEX,INTERPOLATED_SURF_INDEX,DEFAULT_SURF_INDEX=0,INERT_SURF_INDEX=0
REAL(EB), ALLOCATABLE, DIMENSION(:) :: AAS,BBS,CCS,DDS,DDT,RDX_S,RDXN_S,DX_WGT_S, &
                                       K_S,RHOCBAR,C_S,RHO_S,Q_S,KAPPA_S,X_S_NEW
REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: INT_WGT
INTEGER,  ALLOCATABLE, DIMENSION(:) :: LAYER_INDEX

! Divergence Arrays

REAL(EB), ALLOCATABLE, DIMENSION(:,:) :: DSUM,USUM,PSUM

! Tree Arrays
 
INTEGER :: N_TREES
REAL(EB), ALLOCATABLE, DIMENSION(:) :: CANOPY_W,CANOPY_B_H, TREE_H,X_TREE,Y_TREE,Z_TREE
INTEGER, ALLOCATABLE, DIMENSION(:) :: TREE_PARTICLE_CLASS,TREE_MESH
 
! Sprinkler Variables
 
REAL(EB) :: C_DIMARZO=6.E6_EB
INTEGER :: NSTRATA
INTEGER, PARAMETER :: NDC=1000
LOGICAL :: POROUS_FLOOR

! Particles and Droplets
 
INTEGER :: MAXIMUM_DROPLETS,N_PART,PARTICLE_TAG,N_EVAC,N_EVAP_INDICIES=0
 
! Initial value and pressure zone arrays
 
INTEGER :: N_INIT,N_ZONE
 
! Output quantity arrays
 
INTEGER, PARAMETER :: N_OUTPUT_QUANTITIES=280
INTEGER :: PLOT3D_QUANTITY_INDEX(5)
CHARACTER(30) :: PLOT3D_QUANTITY(5)
INTEGER :: N_BNDF,N_ISOF,N_PROF
REAL(EB),ALLOCATABLE, DIMENSION(:) :: HRR,RHRR,CHRR,FHRR,MLR,HRR_SUM,RHRR_SUM,CHRR_SUM,FHRR_SUM,MLR_SUM,HRR_COUNT
REAL(EB),ALLOCATABLE, DIMENSION(:,:) :: MINT,MINT_SUM
REAL(EB),ALLOCATABLE, DIMENSION(:) :: MINT_COUNT

! Clipping values
 
REAL(EB) :: TMPMIN,TMPMAX,YYMIN(20),YYMAX(20),RHOMIN,RHOMAX
 
! CPU and Wall Clock Timings
 
INTEGER, PARAMETER :: N_TIMERS=15
INTEGER, ALLOCATABLE, DIMENSION(:) :: NTCYC,NCYC
REAL(EB), ALLOCATABLE, DIMENSION(:) :: T_PER_STEP,T_ACCUM
REAL(EB) :: WALL_CLOCK_START, WALL_CLOCK_END
 
END MODULE GLOBAL_CONSTANTS
