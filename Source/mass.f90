!> \brief Mass transport equations

MODULE MASS

USE PRECISION_PARAMETERS
USE GLOBAL_CONSTANTS
USE MESH_POINTERS
USE COMP_FUNCTIONS, ONLY: CURRENT_TIME

IMPLICIT NONE (TYPE,EXTERNAL)
PRIVATE
PUBLIC MASS_FINITE_DIFFERENCES,DENSITY

CONTAINS


!> \brief Compute spatial differences for mass transport equations
!> \param NM Mesh index

SUBROUTINE MASS_FINITE_DIFFERENCES(NM)

USE MATH_FUNCTIONS, ONLY: GET_SCALAR_FACE_VALUE

INTEGER, INTENT(IN) :: NM
REAL(EB) :: TNOW
REAL(EB), DIMENSION(0:3,0:3,0:3) :: U_TEMP,Z_TEMP,F_TEMP
REAL(EB), PARAMETER :: DUMMY=0._EB
INTEGER  :: I,J,K,N,IOR,IW,IIG,JJG,KKG,II,JJ,KK
REAL(EB), POINTER, DIMENSION(:,:,:) :: UU,VV,WW,RHOP
REAL(EB), POINTER, DIMENSION(:,:,:,:) :: ZZP
REAL(EB), POINTER, DIMENSION(:,:,:) :: RHO_Z_P
TYPE(WALL_TYPE), POINTER :: WC
TYPE(BOUNDARY_COORD_TYPE), POINTER :: BC
TYPE(BOUNDARY_ONE_D_TYPE), POINTER :: ONE_D

IF (SOLID_PHASE_ONLY) RETURN

TNOW=CURRENT_TIME()
CALL POINT_TO_MESH(NM)

IF (PREDICTOR) THEN
   UU => U
   VV => V
   WW => W
   RHOP => RHO
   ZZP => ZZ
ELSE
   UU => US
   VV => VS
   WW => WS
   RHOP => RHOS
   ZZP => ZZS
ENDIF

! Reset counter for CLIP_RHOMIN, CLIP_RHOMAX
! Done here so DT_RESTRICT_COUNT will persist until WRITE_DIAGNOSTICS is called

IF (PREDICTOR) DT_RESTRICT_COUNT = 0

! Species face values

SPECIES_LOOP: DO N=1,N_TOTAL_SCALARS

   RHO_Z_P=>WORK1

   !$OMP PARALLEL DO
   DO K=0,KBP1
      DO J=0,JBP1
         DO I=0,IBP1
            RHO_Z_P(I,J,K) = RHOP(I,J,K)*ZZP(I,J,K,N)
         ENDDO
      ENDDO
   ENDDO
   !$OMP END PARALLEL DO

   ! Compute scalar face values

   CALL GET_SCALAR_FACE_VALUE(UU,RHO_Z_P,FX(:,:,:,N),1,IBM1,1,JBAR,1,KBAR,1,I_FLUX_LIMITER)
   CALL GET_SCALAR_FACE_VALUE(VV,RHO_Z_P,FY(:,:,:,N),1,IBAR,1,JBM1,1,KBAR,2,I_FLUX_LIMITER)
   CALL GET_SCALAR_FACE_VALUE(WW,RHO_Z_P,FZ(:,:,:,N),1,IBAR,1,JBAR,1,KBM1,3,I_FLUX_LIMITER)

   !$OMP PARALLEL DO PRIVATE(IW,WC,BC,ONE_D,II,JJ,KK,IIG,JJG,KKG,IOR,U_TEMP,Z_TEMP,F_TEMP)
   WALL_LOOP_2: DO IW=1,N_EXTERNAL_WALL_CELLS+N_INTERNAL_WALL_CELLS
      WC=>WALL(IW)
      IF (WC%BOUNDARY_TYPE==NULL_BOUNDARY) CYCLE WALL_LOOP_2
      BC=>BOUNDARY_COORD(WC%BC_INDEX)
      ONE_D=>BOUNDARY_ONE_D(WC%OD_INDEX)

      II  = BC%II
      JJ  = BC%JJ
      KK  = BC%KK
      IIG = BC%IIG
      JJG = BC%JJG
      KKG = BC%KKG
      IOR = BC%IOR

      IF (WC%BOUNDARY_TYPE==SOLID_BOUNDARY .AND. .NOT.SOLID(CELL_INDEX(II,JJ,KK)) .AND. .NOT.EXTERIOR(CELL_INDEX(II,JJ,KK))) THEN
         SELECT CASE(IOR)
            CASE( 1); FX(IIG-1,JJG,KKG,N) = 0._EB
            CASE(-1); FX(IIG,JJG,KKG,N)   = 0._EB
            CASE( 2); FY(IIG,JJG-1,KKG,N) = 0._EB
            CASE(-2); FY(IIG,JJG,KKG,N)   = 0._EB
            CASE( 3); FZ(IIG,JJG,KKG-1,N) = 0._EB
            CASE(-3); FZ(IIG,JJG,KKG,N)   = 0._EB
         END SELECT
      ELSE
         SELECT CASE(IOR)
            CASE( 1); FX(IIG-1,JJG,KKG,N) = ONE_D%RHO_F*ONE_D%ZZ_F(N)
            CASE(-1); FX(IIG,JJG,KKG,N)   = ONE_D%RHO_F*ONE_D%ZZ_F(N)
            CASE( 2); FY(IIG,JJG-1,KKG,N) = ONE_D%RHO_F*ONE_D%ZZ_F(N)
            CASE(-2); FY(IIG,JJG,KKG,N)   = ONE_D%RHO_F*ONE_D%ZZ_F(N)
            CASE( 3); FZ(IIG,JJG,KKG-1,N) = ONE_D%RHO_F*ONE_D%ZZ_F(N)
            CASE(-3); FZ(IIG,JJG,KKG,N)   = ONE_D%RHO_F*ONE_D%ZZ_F(N)
         END SELECT
      ENDIF

      ! Overwrite first off-wall advective flux if flow is away from the wall and if the face is not also a wall cell

      OFF_WALL_IF_2: IF (WC%BOUNDARY_TYPE/=INTERPOLATED_BOUNDARY .AND. WC%BOUNDARY_TYPE/=OPEN_BOUNDARY) THEN

         OFF_WALL_SELECT_2: SELECT CASE(IOR)
            CASE( 1) OFF_WALL_SELECT_2
               !      ghost          FX/UU(II+1)
               ! ///   II   ///  II+1  |  II+2  | ...
               !                       ^ WALL_INDEX(II+1,+1)
               IF ((UU(II+1,JJ,KK)>0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II+1,JJ,KK),+1)>0)) THEN
                  Z_TEMP(0:3,1,1) = (/RHO_Z_P(II+1,JJ,KK),RHO_Z_P(II+1:II+2,JJ,KK),DUMMY/)
                  U_TEMP(1,1,1) = UU(II+1,JJ,KK)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,1,I_FLUX_LIMITER)
                  FX(II+1,JJ,KK,N) = F_TEMP(1,1,1)
               ENDIF
            CASE(-1) OFF_WALL_SELECT_2
               !            FX/UU(II-2)     ghost
               ! ... |  II-2  |  II-1  ///   II   ///
               !              ^ WALL_INDEX(II-1,-1)
               IF ((UU(II-2,JJ,KK)<0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II-1,JJ,KK),-1)>0)) THEN
                  Z_TEMP(0:3,1,1) = (/DUMMY,RHO_Z_P(II-2:II-1,JJ,KK),RHO_Z_P(II-1,JJ,KK)/)
                  U_TEMP(1,1,1) = UU(II-2,JJ,KK)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,1,I_FLUX_LIMITER)
                  FX(II-2,JJ,KK,N) = F_TEMP(1,1,1)
               ENDIF
            CASE( 2) OFF_WALL_SELECT_2
               IF ((VV(II,JJ+1,KK)>0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II,JJ+1,KK),+2)>0)) THEN
                  Z_TEMP(1,0:3,1) = (/RHO_Z_P(II,JJ+1,KK),RHO_Z_P(II,JJ+1:JJ+2,KK),DUMMY/)
                  U_TEMP(1,1,1) = VV(II,JJ+1,KK)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,2,I_FLUX_LIMITER)
                  FY(II,JJ+1,KK,N) = F_TEMP(1,1,1)
               ENDIF
            CASE(-2) OFF_WALL_SELECT_2
               IF ((VV(II,JJ-2,KK)<0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II,JJ-1,KK),-2)>0)) THEN
                  Z_TEMP(1,0:3,1) = (/DUMMY,RHO_Z_P(II,JJ-2:JJ-1,KK),RHO_Z_P(II,JJ-1,KK)/)
                  U_TEMP(1,1,1) = VV(II,JJ-2,KK)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,2,I_FLUX_LIMITER)
                  FY(II,JJ-2,KK,N) = F_TEMP(1,1,1)
               ENDIF
            CASE( 3) OFF_WALL_SELECT_2
               IF ((WW(II,JJ,KK+1)>0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II,JJ,KK+1),+3)>0)) THEN
                  Z_TEMP(1,1,0:3) = (/RHO_Z_P(II,JJ,KK+1),RHO_Z_P(II,JJ,KK+1:KK+2),DUMMY/)
                  U_TEMP(1,1,1) = WW(II,JJ,KK+1)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,3,I_FLUX_LIMITER)
                  FZ(II,JJ,KK+1,N) = F_TEMP(1,1,1)
               ENDIF
            CASE(-3) OFF_WALL_SELECT_2
               IF ((WW(II,JJ,KK-2)<0._EB) .AND. .NOT.(WALL_INDEX(CELL_INDEX(II,JJ,KK-1),-3)>0)) THEN
                  Z_TEMP(1,1,0:3) = (/DUMMY,RHO_Z_P(II,JJ,KK-2:KK-1),RHO_Z_P(II,JJ,KK-1)/)
                  U_TEMP(1,1,1) = WW(II,JJ,KK-2)
                  CALL GET_SCALAR_FACE_VALUE(U_TEMP,Z_TEMP,F_TEMP,1,1,1,1,1,1,3,I_FLUX_LIMITER)
                  FZ(II,JJ,KK-2,N) = F_TEMP(1,1,1)
               ENDIF
         END SELECT OFF_WALL_SELECT_2

      ENDIF OFF_WALL_IF_2

   ENDDO WALL_LOOP_2
   !$OMP END PARALLEL DO

ENDDO SPECIES_LOOP

T_USED(3)=T_USED(3)+CURRENT_TIME()-TNOW
END SUBROUTINE MASS_FINITE_DIFFERENCES


!> \brief Update the species mass fractions and density
!> \param T Simulation time (s)
!> \param DT Time step (s)
!> \param NM Mesh index

SUBROUTINE DENSITY(T,DT,NM)

USE PHYSICAL_FUNCTIONS, ONLY : GET_SPECIFIC_GAS_CONSTANT
USE MANUFACTURED_SOLUTIONS, ONLY: VD2D_MMS_Z_OF_RHO,VD2D_MMS_Z_SRC,UF_MMS,WF_MMS,VD2D_MMS_RHO_OF_Z,VD2D_MMS_Z_SRC
USE SOOT_ROUTINES, ONLY: SETTLING_VELOCITY
USE CC_SCALARS, ONLY : SET_EXIMADVFLX_3D,ROTATED_CUBE_RHS_ZZ

INTEGER, INTENT(IN) :: NM
REAL(EB), INTENT(IN) :: T,DT
REAL(EB) :: TNOW,RHS,Q_Z,XHAT,ZHAT
REAL(EB), ALLOCATABLE, DIMENSION(:) :: ZZ_GET
INTEGER :: I,J,K,N,IW
REAL(EB), POINTER, DIMENSION(:,:,:,:) :: DEL_RHO_D_DEL_Z__0
REAL(EB), POINTER, DIMENSION(:,:,:) :: UU,VV,WW
TYPE(WALL_TYPE), POINTER :: WC
TYPE(BOUNDARY_COORD_TYPE), POINTER :: BC

IF (SOLID_PHASE_ONLY) RETURN

! If the RHS of the continuity equation does not yet satisfy the divergence constraint, return.
! This is typical of the case where an initial velocity field is specified by the user.

SELECT CASE (PERIODIC_TEST)
   CASE DEFAULT
      IF (ICYC<=1) RETURN
   CASE (5,8)
      RETURN
   CASE (4,7,11,21,22)
END SELECT

TNOW=CURRENT_TIME()
CALL POINT_TO_MESH(NM)

UU=>WORK1
VV=>WORK2
WW=>WORK3
DEL_RHO_D_DEL_Z__0=>SCALAR_WORK4

PREDICTOR_STEP: SELECT CASE (PREDICTOR)

CASE(.TRUE.) PREDICTOR_STEP

   IF (FIRST_PASS) THEN
      ! This IF is required because DEL_RHO_D_DEL_Z is updated to the next time level in divg within
      ! the CHANGE_TIME_STEP loop in main while we are determining the appropriate stable DT.
      IF (ANY(SPECIES_MIXTURE%DEPOSITING) .AND. (GRAVITATIONAL_SETTLING .OR. THERMOPHORETIC_SETTLING)) CALL SETTLING_VELOCITY(NM)
      DEL_RHO_D_DEL_Z__0 = DEL_RHO_D_DEL_Z
   ENDIF

   ! Correct boundary velocity at wall cells

   UU=U
   VV=V
   WW=W

   !$OMP PARALLEL

   !$OMP DO PRIVATE(IW,WC,BC)
   WALL_LOOP: DO IW=1,N_EXTERNAL_WALL_CELLS
      WC=>WALL(IW)
      IF (WC%BOUNDARY_TYPE/=INTERPOLATED_BOUNDARY) CYCLE WALL_LOOP
      BC=>BOUNDARY_COORD(WC%BC_INDEX)
      SELECT CASE(BC%IOR)
         CASE( 1); UU(BC%IIG-1,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE(-1); UU(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE( 2); VV(BC%IIG  ,BC%JJG-1,BC%KKG  ) = UVW_SAVE(IW)
         CASE(-2); VV(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE( 3); WW(BC%IIG  ,BC%JJG  ,BC%KKG-1) = UVW_SAVE(IW)
         CASE(-3); WW(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
      END SELECT
   ENDDO WALL_LOOP
   !$OMP END DO

   ! Predictor step for mass density

   !$OMP DO PRIVATE(N,I,J,K,RHS)
   DO N=1,N_TOTAL_SCALARS
      DO K=1,KBAR
         DO J=1,JBAR
            DO I=1,IBAR
               IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
               RHS = - DEL_RHO_D_DEL_Z__0(I,J,K,N) &
                   + (FX(I,J,K,N)*UU(I,J,K)*R(I) - FX(I-1,J,K,N)*UU(I-1,J,K)*R(I-1))*RDX(I)*RRN(I) &
                   + (FY(I,J,K,N)*VV(I,J,K)      - FY(I,J-1,K,N)*VV(I,J-1,K)       )*RDY(J)        &
                   + (FZ(I,J,K,N)*WW(I,J,K)      - FZ(I,J,K-1,N)*WW(I,J,K-1)       )*RDZ(K)
               ZZS(I,J,K,N) = RHO(I,J,K)*ZZ(I,J,K,N) - DT*RHS
            ENDDO
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   !$OMP END PARALLEL

   IF (CC_IBM) CALL SET_EXIMADVFLX_3D(NM,UU,VV,WW)
   IF (STORE_SPECIES_FLUX) THEN
      DO N=1,N_TOTAL_SCALARS
         ADV_FX(:,:,:,N) = FX(:,:,:,N)*UU(:,:,:)
         ADV_FY(:,:,:,N) = FY(:,:,:,N)*VV(:,:,:)
         ADV_FZ(:,:,:,N) = FZ(:,:,:,N)*WW(:,:,:)
      ENDDO
   ENDIF

   ! Add gas production source term

   IF (N_LP_ARRAY_INDICES>0 .OR. N_REACTIONS>0 .OR. ANY(SPECIES_MIXTURE%DEPOSITING) .OR. &
       ANY(SPECIES_MIXTURE%CONDENSATION_SMIX_INDEX>0) .OR. REACTING_THIN_OBSTRUCTIONS) ZZS = ZZS + DT*M_DOT_PPP

   ! Manufactured solution

   IF (PERIODIC_TEST==7) THEN
      DO K=1,KBAR
         DO J=1,JBAR
            DO I=1,IBAR
               ! divergence from EOS
               XHAT = XC(I) - UF_MMS*T
               ZHAT = ZC(K) - WF_MMS*T
               Q_Z = VD2D_MMS_Z_SRC(XHAT,ZHAT,T)
               ZZS(I,J,K,1) = ZZS(I,J,K,1) - DT*Q_Z
               ZZS(I,J,K,2) = ZZS(I,J,K,2) + DT*Q_Z
            ENDDO
         ENDDO
      ENDDO
   ELSEIF(PERIODIC_TEST==21 .OR. PERIODIC_TEST==22 .OR. PERIODIC_TEST==23) THEN
      CALL ROTATED_CUBE_RHS_ZZ(T,DT,NM)
   ENDIF

   !$OMP PARALLEL PRIVATE(ZZ_GET)

   ! Get rho = sum(rho*Y_alpha)

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            RHOS(I,J,K) = SUM(ZZS(I,J,K,1:N_TRACKED_SPECIES))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Check mass density for positivity

   !$OMP MASTER
   CALL CHECK_MASS_DENSITY
   !$OMP END MASTER
   !$OMP BARRIER

   ALLOCATE(ZZ_GET(1:N_TOTAL_SCALARS))

   ! Extract mass fraction from RHO * ZZ

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            ZZS(I,J,K,1:N_TOTAL_SCALARS) = ZZS(I,J,K,1:N_TOTAL_SCALARS)/RHOS(I,J,K)
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Passive scalars

   !$OMP MASTER
   CALL CLIP_PASSIVE_SCALARS
   !$OMP END MASTER
   !$OMP BARRIER

   ! Predict background pressure at next time step

   !$OMP MASTER
   DO I=1,N_ZONE
      PBAR_S(:,I) = PBAR(:,I) + D_PBAR_DT(I)*DT
   ENDDO
   !$OMP END MASTER
   !$OMP BARRIER

   ! Compute molecular weight term RSUM=R0*SUM(Y_i/W_i)

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            ZZ_GET(1:N_TRACKED_SPECIES) = ZZS(I,J,K,1:N_TRACKED_SPECIES)
            CALL GET_SPECIFIC_GAS_CONSTANT(ZZ_GET,RSUM(I,J,K))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Extract predicted temperature at next time step from Equation of State

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            TMP(I,J,K) = PBAR_S(K,PRESSURE_ZONE(I,J,K))/(RSUM(I,J,K)*RHOS(I,J,K))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   DEALLOCATE(ZZ_GET)

   !$OMP END PARALLEL

CASE(.FALSE.) PREDICTOR_STEP  ! CORRECTOR step

   ! Correct boundary velocity at wall cells

   UU=US
   VV=VS
   WW=WS

   !$OMP PARALLEL

   !$OMP DO PRIVATE(IW,WC,BC)
   WALL_LOOP_2: DO IW=1,N_EXTERNAL_WALL_CELLS
      WC => WALL(IW)
      IF (WC%BOUNDARY_TYPE/=INTERPOLATED_BOUNDARY) CYCLE WALL_LOOP_2
      BC => BOUNDARY_COORD(WC%BC_INDEX)
      SELECT CASE(BC%IOR)
         CASE( 1); UU(BC%IIG-1,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE(-1); UU(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE( 2); VV(BC%IIG  ,BC%JJG-1,BC%KKG  ) = UVW_SAVE(IW)
         CASE(-2); VV(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
         CASE( 3); WW(BC%IIG  ,BC%JJG  ,BC%KKG-1) = UVW_SAVE(IW)
         CASE(-3); WW(BC%IIG  ,BC%JJG  ,BC%KKG  ) = UVW_SAVE(IW)
      END SELECT
   ENDDO WALL_LOOP_2
   !$OMP END DO

   !$OMP MASTER
   IF (ANY(SPECIES_MIXTURE%DEPOSITING) .AND. (GRAVITATIONAL_SETTLING .OR. THERMOPHORETIC_SETTLING)) CALL SETTLING_VELOCITY(NM)
   !$OMP END MASTER
   !$OMP BARRIER

   ! Compute species mass density at the next time step

   !$OMP DO PRIVATE(N,I,J,K,RHS)
   DO N=1,N_TOTAL_SCALARS
      DO K=1,KBAR
         DO J=1,JBAR
            DO I=1,IBAR
               IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
               RHS = - DEL_RHO_D_DEL_Z(I,J,K,N) &
                   + (FX(I,J,K,N)*UU(I,J,K)*R(I) - FX(I-1,J,K,N)*UU(I-1,J,K)*R(I-1))*RDX(I)*RRN(I) &
                   + (FY(I,J,K,N)*VV(I,J,K)      - FY(I,J-1,K,N)*VV(I,J-1,K)       )*RDY(J)        &
                   + (FZ(I,J,K,N)*WW(I,J,K)      - FZ(I,J,K-1,N)*WW(I,J,K-1)       )*RDZ(K)
               ZZ(I,J,K,N) = .5_EB*( RHO(I,J,K)*ZZ(I,J,K,N) + RHOS(I,J,K)*ZZS(I,J,K,N) - DT*RHS )
            ENDDO
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   !$OMP END PARALLEL

   ! Add gas production source term

   IF (N_LP_ARRAY_INDICES>0 .OR. N_REACTIONS>0 .OR. ANY(SPECIES_MIXTURE%DEPOSITING) .OR. &
       ANY(SPECIES_MIXTURE%CONDENSATION_SMIX_INDEX>0) .OR. REACTING_THIN_OBSTRUCTIONS) THEN
      ZZ = ZZ + 0.5_EB*DT*M_DOT_PPP
      IF (.NOT. CC_IBM) THEN ! We will use these for Regular cells in cut-cell region in CC_DENSITY.
         M_DOT_PPP = 0._EB
         D_SOURCE  = 0._EB
      ENDIF
   ENDIF

   IF (CC_IBM) CALL SET_EXIMADVFLX_3D(NM,UU,VV,WW)
   IF (STORE_SPECIES_FLUX) THEN
      DO N=1,N_TOTAL_SCALARS
         ADV_FX(:,:,:,N) = 0.5_EB*( ADV_FX(:,:,:,N) + FX(:,:,:,N)*UU(:,:,:) )
         ADV_FY(:,:,:,N) = 0.5_EB*( ADV_FY(:,:,:,N) + FY(:,:,:,N)*VV(:,:,:) )
         ADV_FZ(:,:,:,N) = 0.5_EB*( ADV_FZ(:,:,:,N) + FZ(:,:,:,N)*WW(:,:,:) )
      ENDDO
   ENDIF

   ! Manufactured solution

   IF (PERIODIC_TEST==7) THEN
      DO K=1,KBAR
         DO J=1,JBAR
            DO I=1,IBAR
               ! divergence from EOS
               XHAT = XC(I) - UF_MMS*T
               ZHAT = ZC(K) - WF_MMS*T
               Q_Z = VD2D_MMS_Z_SRC(XHAT,ZHAT,T)
               ZZ(I,J,K,1) = ZZ(I,J,K,1) - .5_EB*DT*Q_Z
               ZZ(I,J,K,2) = ZZ(I,J,K,2) + .5_EB*DT*Q_Z
            ENDDO
         ENDDO
      ENDDO
   ELSEIF(PERIODIC_TEST==21 .OR. PERIODIC_TEST==22 .OR. PERIODIC_TEST==23) THEN
      CALL ROTATED_CUBE_RHS_ZZ(T,DT,NM)
   ENDIF

   ! Get rho = sum(rho*Y_alpha)

   !$OMP PARALLEL PRIVATE(ZZ_GET)

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            RHO(I,J,K) = SUM(ZZ(I,J,K,1:N_TRACKED_SPECIES))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Check mass density for positivity

   !$OMP MASTER
   CALL CHECK_MASS_DENSITY
   !$OMP END MASTER
   !$OMP BARRIER

   ALLOCATE(ZZ_GET(1:N_TOTAL_SCALARS))

   ! Extract Y_n from rho*Y_n

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            ZZ(I,J,K,1:N_TOTAL_SCALARS) = ZZ(I,J,K,1:N_TOTAL_SCALARS)/RHO(I,J,K)
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Passive scalars

   !$OMP MASTER
   CALL CLIP_PASSIVE_SCALARS
   !$OMP END MASTER
   !$OMP BARRIER

   ! Correct background pressure

   !$OMP MASTER
   DO I=1,N_ZONE
      PBAR(:,I) = 0.5_EB*(PBAR(:,I) + PBAR_S(:,I) + D_PBAR_DT_S(I)*DT)
   ENDDO
   !$OMP END MASTER
   !$OMP BARRIER

   ! Compute molecular weight term RSUM=R0*SUM(Y_i/W_i)

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            ZZ_GET(1:N_TRACKED_SPECIES) = ZZ(I,J,K,1:N_TRACKED_SPECIES)
            CALL GET_SPECIFIC_GAS_CONSTANT(ZZ_GET,RSUM(I,J,K))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   ! Extract predicted temperature at next time step from Equation of State

   !$OMP DO
   DO K=1,KBAR
      DO J=1,JBAR
         DO I=1,IBAR
            IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
            TMP(I,J,K) = PBAR(K,PRESSURE_ZONE(I,J,K))/(RSUM(I,J,K)*RHO(I,J,K))
         ENDDO
      ENDDO
   ENDDO
   !$OMP END DO

   DEALLOCATE(ZZ_GET)

   !$OMP END PARALLEL

END SELECT PREDICTOR_STEP

T_USED(3)=T_USED(3)+CURRENT_TIME()-TNOW

CONTAINS

!> \brief Redistribute mass from cells below or above the density cut-off limits
!> \details Do not apply OpenMP to this routine

SUBROUTINE CHECK_MASS_DENSITY

REAL(EB) :: MASS_N(-3:3),CONST,MASS_C,RHO_ZZ_CUT,RHO_CUT,VC(-3:3),SIGN_FACTOR,SUM_MASS_N,VC1(-3:3),RHO_ZZ_MIN,RHO_ZZ_MAX,&
            RHO_ZZ_TMP(1:N_TRACKED_SPECIES)
INTEGER  :: IC,NN
REAL(EB), POINTER, DIMENSION(:,:,:) :: DELTA_RHO,DELTA_RHO_ZZ,RHOP
REAL(EB), POINTER, DIMENSION(:,:,:,:) :: RHO_ZZ

DELTA_RHO => WORK4
DELTA_RHO =  0._EB
CLIP_RHOMIN = .FALSE.
CLIP_RHOMAX = .FALSE.

IF (PREDICTOR) THEN
   RHO_ZZ => ZZS  ! At this stage of the time step, ZZS is actually RHOS*ZZS
   RHOP   => RHOS
ELSE
   RHO_ZZ => ZZ   ! At this stage of the time step, ZZ is actually RHO*ZZ
   RHOP   => RHO
ENDIF

! Correct density

DO K=1,KBAR
   DO J=1,JBAR
      VC1( 0)  = DY(J)  *DZ(K)
      VC1(-1)  = VC1( 0)
      VC1( 1)  = VC1( 0)
      VC1(-2)  = DY(J-1)*DZ(K)
      VC1( 2)  = DY(J+1)*DZ(K)
      VC1(-3)  = DY(J)  *DZ(K-1)
      VC1( 3)  = DY(J)  *DZ(K+1)
      DO I=1,IBAR
         IF (RHOP(I,J,K)>=RHOMIN .AND. RHOP(I,J,K)<=RHOMAX) CYCLE
         IC = CELL_INDEX(I,J,K)
         IF (SOLID(IC)) CYCLE
         IF (RHOP(I,J,K)<RHOMIN) THEN
            RHO_CUT = RHOMIN
            SIGN_FACTOR = 1._EB
            CLIP_RHOMIN = .TRUE.
         ELSE
            RHO_CUT = RHOMAX
            SIGN_FACTOR = -1._EB
            CLIP_RHOMAX = .TRUE.
         ENDIF
         MASS_N = 0._EB
         VC( 0)  = DX(I)  * VC1( 0)
         VC(-1)  = DX(I-1)* VC1(-1)
         VC( 1)  = DX(I+1)* VC1( 1)
         VC(-2)  = DX(I)  * VC1(-2)
         VC( 2)  = DX(I)  * VC1( 2)
         VC(-3)  = DX(I)  * VC1(-3)
         VC( 3)  = DX(I)  * VC1( 3)

         MASS_C = ABS(RHO_CUT-RHOP(I,J,K))*VC(0)
         IF (WALL_INDEX(IC,-1)==0) MASS_N(-1) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I-1,J,K)))-RHO_CUT)*VC(-1)
         IF (WALL_INDEX(IC, 1)==0) MASS_N( 1) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I+1,J,K)))-RHO_CUT)*VC( 1)
         IF (WALL_INDEX(IC,-2)==0) MASS_N(-2) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I,J-1,K)))-RHO_CUT)*VC(-2)
         IF (WALL_INDEX(IC, 2)==0) MASS_N( 2) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I,J+1,K)))-RHO_CUT)*VC( 2)
         IF (WALL_INDEX(IC,-3)==0) MASS_N(-3) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I,J,K-1)))-RHO_CUT)*VC(-3)
         IF (WALL_INDEX(IC, 3)==0) MASS_N( 3) = ABS(MIN(RHOMAX,MAX(RHOMIN,RHOP(I,J,K+1)))-RHO_CUT)*VC( 3)
         SUM_MASS_N = SUM(MASS_N)
         IF (SUM_MASS_N<=TWO_EPSILON_EB) CYCLE
         CONST = SIGN_FACTOR*MIN(1._EB,MASS_C/SUM_MASS_N)
         DELTA_RHO(I,J,K)   = DELTA_RHO(I,J,K)   + CONST*SUM_MASS_N/VC( 0)
         DELTA_RHO(I-1,J,K) = DELTA_RHO(I-1,J,K) - CONST*MASS_N(-1)/VC(-1)
         DELTA_RHO(I+1,J,K) = DELTA_RHO(I+1,J,K) - CONST*MASS_N( 1)/VC( 1)
         DELTA_RHO(I,J-1,K) = DELTA_RHO(I,J-1,K) - CONST*MASS_N(-2)/VC(-2)
         DELTA_RHO(I,J+1,K) = DELTA_RHO(I,J+1,K) - CONST*MASS_N( 2)/VC( 2)
         DELTA_RHO(I,J,K-1) = DELTA_RHO(I,J,K-1) - CONST*MASS_N(-3)/VC(-3)
         DELTA_RHO(I,J,K+1) = DELTA_RHO(I,J,K+1) - CONST*MASS_N( 3)/VC( 3)
      ENDDO
   ENDDO
ENDDO

RHOP(1:IBAR,1:JBAR,1:KBAR) = MIN(RHOMAX,MAX(RHOMIN,RHOP(1:IBAR,1:JBAR,1:KBAR)+DELTA_RHO(1:IBAR,1:JBAR,1:KBAR)))

! Correct species mass density

RHO_ZZ_MIN = 0._EB

SPECIES_LOOP: DO N=1,N_TRACKED_SPECIES

DELTA_RHO_ZZ => WORK5
DELTA_RHO_ZZ = 0._EB

DO K=1,KBAR
   DO J=1,JBAR
      VC1( 0)  = DY(J)  *DZ(K)
      VC1(-1)  = VC1( 0)
      VC1( 1)  = VC1( 0)
      VC1(-2)  = DY(J-1)*DZ(K)
      VC1( 2)  = DY(J+1)*DZ(K)
      VC1(-3)  = DY(J)  *DZ(K-1)
      VC1( 3)  = DY(J)  *DZ(K+1)
      DO I=1,IBAR

         RHO_ZZ_MAX = RHOP(I,J,K)

         IF (RHO_ZZ(I,J,K,N)>=RHO_ZZ_MIN .AND. RHO_ZZ(I,J,K,N)<=RHO_ZZ_MAX) CYCLE
         IC = CELL_INDEX(I,J,K)
         IF (SOLID(IC)) CYCLE
         IF (RHO_ZZ(I,J,K,N)<RHO_ZZ_MIN) THEN
            RHO_ZZ_CUT = RHO_ZZ_MIN
            SIGN_FACTOR = 1._EB
         ELSE
            RHO_ZZ_CUT = RHO_ZZ_MAX
            SIGN_FACTOR = -1._EB
         ENDIF
         MASS_N = 0._EB
         VC( 0)  = DX(I)  * VC1( 0)
         VC(-1)  = DX(I-1)* VC1(-1)
         VC( 1)  = DX(I+1)* VC1( 1)
         VC(-2)  = DX(I)  * VC1(-2)
         VC( 2)  = DX(I)  * VC1( 2)
         VC(-3)  = DX(I)  * VC1(-3)
         VC( 3)  = DX(I)  * VC1( 3)

         MASS_C = ABS(RHO_ZZ_CUT-RHO_ZZ(I,J,K,N))*VC(0)
         IF (WALL_INDEX(IC,-1)==0) MASS_N(-1) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I-1,J,K,N)))-RHO_ZZ_CUT)*VC(-1)
         IF (WALL_INDEX(IC, 1)==0) MASS_N( 1) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I+1,J,K,N)))-RHO_ZZ_CUT)*VC( 1)
         IF (WALL_INDEX(IC,-2)==0) MASS_N(-2) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I,J-1,K,N)))-RHO_ZZ_CUT)*VC(-2)
         IF (WALL_INDEX(IC, 2)==0) MASS_N( 2) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I,J+1,K,N)))-RHO_ZZ_CUT)*VC( 2)
         IF (WALL_INDEX(IC,-3)==0) MASS_N(-3) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I,J,K-1,N)))-RHO_ZZ_CUT)*VC(-3)
         IF (WALL_INDEX(IC, 3)==0) MASS_N( 3) = ABS(MIN(RHO_ZZ_MAX,MAX(RHO_ZZ_MIN,RHO_ZZ(I,J,K+1,N)))-RHO_ZZ_CUT)*VC( 3)
         SUM_MASS_N = SUM(MASS_N)
         IF (SUM_MASS_N<=TWO_EPSILON_EB) CYCLE
         CONST = SIGN_FACTOR*MIN(1._EB,MASS_C/SUM_MASS_N)
         DELTA_RHO_ZZ(I,J,K)   = DELTA_RHO_ZZ(I,J,K)   + CONST*SUM_MASS_N/VC( 0)
         DELTA_RHO_ZZ(I-1,J,K) = DELTA_RHO_ZZ(I-1,J,K) - CONST*MASS_N(-1)/VC(-1)
         DELTA_RHO_ZZ(I+1,J,K) = DELTA_RHO_ZZ(I+1,J,K) - CONST*MASS_N( 1)/VC( 1)
         DELTA_RHO_ZZ(I,J-1,K) = DELTA_RHO_ZZ(I,J-1,K) - CONST*MASS_N(-2)/VC(-2)
         DELTA_RHO_ZZ(I,J+1,K) = DELTA_RHO_ZZ(I,J+1,K) - CONST*MASS_N( 2)/VC( 2)
         DELTA_RHO_ZZ(I,J,K-1) = DELTA_RHO_ZZ(I,J,K-1) - CONST*MASS_N(-3)/VC(-3)
         DELTA_RHO_ZZ(I,J,K+1) = DELTA_RHO_ZZ(I,J,K+1) - CONST*MASS_N( 3)/VC( 3)
      ENDDO
   ENDDO
ENDDO

DO K=1,KBAR
   DO J=1,JBAR
      DO I=1,IBAR
         RHO_ZZ(I,J,K,N) = MIN(RHOP(I,J,K),MAX(RHO_ZZ_MIN,RHO_ZZ(I,J,K,N)+DELTA_RHO_ZZ(I,J,K)))
      ENDDO
   ENDDO
ENDDO

ENDDO SPECIES_LOOP

! Absorb error in most abundant species or renormalize

DO K=1,KBAR
   DO J=1,JBAR
      DO I=1,IBAR
         IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
         RHO_ZZ_TMP = MAX(0._EB,RHO_ZZ(I,J,K,1:N_TRACKED_SPECIES))
         N=MAXLOC(RHO_ZZ(I,J,K,1:N_TRACKED_SPECIES),1)
         RHO_ZZ(I,J,K,N) = RHOP(I,J,K) - ( SUM(RHO_ZZ(I,J,K,1:N_TRACKED_SPECIES)) - RHO_ZZ(I,J,K,N) )
         NN=MAXLOC(RHO_ZZ(I,J,K,1:N_TRACKED_SPECIES),1) ! recheck most abundant species
         IF (NN/=N) THEN ! includes the case RHO_ZZ(I,J,K,N)<0, assuming initial ALL(RHO_ZZ_TMP>=0.)
            ! if most abundant species changes, then renormalize the mass fractions instead
            RHO_ZZ(I,J,K,1:N_TRACKED_SPECIES) = RHOP(I,J,K) * &
              MAX(0._EB, MIN(1._EB, RHO_ZZ_TMP(1:N_TRACKED_SPECIES)/SUM(RHO_ZZ_TMP(1:N_TRACKED_SPECIES)) ))
         ENDIF
      ENDDO
   ENDDO
ENDDO

END SUBROUTINE CHECK_MASS_DENSITY


SUBROUTINE CLIP_PASSIVE_SCALARS

! Currently only set up for unmixed fraction, zeta

REAL(EB), POINTER, DIMENSION(:,:,:,:) :: ZZP

IF (N_PASSIVE_SCALARS==0) RETURN

IF (PREDICTOR) THEN
   ZZP=>ZZS
ELSE
   ZZP=>ZZ
ENDIF

DO K=1,KBAR
   DO J=1,JBAR
      DO I=1,IBAR
         IF (SOLID(CELL_INDEX(I,J,K))) CYCLE
         ZZP(I,J,K,ZETA_INDEX) = MAX(0._EB,MIN(1._EB,ZZP(I,J,K,ZETA_INDEX)))
      ENDDO
   ENDDO
ENDDO

END SUBROUTINE CLIP_PASSIVE_SCALARS

END SUBROUTINE DENSITY

END MODULE MASS
