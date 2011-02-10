MODULE deck_control_block

  USE strings_advanced
  USE fields

  IMPLICIT NONE

  SAVE
  INTEGER, PARAMETER :: control_block_elements = 11 + 4 * c_ndims
  LOGICAL, DIMENSION(control_block_elements) :: control_block_done = .FALSE.
  CHARACTER(LEN=string_length), DIMENSION(control_block_elements) :: &
      control_block_name = (/ &
          "nx                ", &
          "ny                ", &
          "nz                ", &
          "x_min             ", &
          "x_max             ", &
          "y_min             ", &
          "y_max             ", &
          "z_min             ", &
          "z_max             ", &
          "nprocx            ", &
          "nprocy            ", &
          "nprocz            ", &
          "npart             ", &
          "nsteps            ", &
          "t_end             ", &
          "dt_multiplier     ", &
          "dlb_threshold     ", &
          "icfile            ", &
          "restart_snapshot  ", &
          "neutral_background", &
          "field_order       ", &
          "stdout_frequency  ", &
          "use_random_seed   " /)
  CHARACTER(LEN=string_length), DIMENSION(control_block_elements) :: &
      alternate_name = (/ &
          "nx                ", &
          "ny                ", &
          "nz                ", &
          "x_start           ", &
          "x_end             ", &
          "y_start           ", &
          "y_end             ", &
          "z_start           ", &
          "z_end             ", &
          "nprocx            ", &
          "nprocy            ", &
          "nprocz            ", &
          "npart             ", &
          "nsteps            ", &
          "t_end             ", &
          "dt_multiplier     ", &
          "dlb_threshold     ", &
          "icfile            ", &
          "restart_snapshot  ", &
          "neutral_background", &
          "field_order       ", &
          "stdout_frequency  ", &
          "use_random_seed   " /)

CONTAINS

  FUNCTION handle_control_deck(element, value)

    CHARACTER(*), INTENT(IN) :: element, value
    INTEGER :: handle_control_deck
    INTEGER :: loop, elementselected, field_order, ierr, io

    handle_control_deck = c_err_unknown_element

    elementselected = 0

    DO loop = 1, control_block_elements
      IF (str_cmp(element, TRIM(ADJUSTL(control_block_name(loop)))) &
          .OR. str_cmp(element, TRIM(ADJUSTL(alternate_name(loop))))) THEN
        elementselected = loop
        EXIT
      ENDIF
    ENDDO

    IF (elementselected .EQ. 0) RETURN
    IF (control_block_done(elementselected)) THEN
      handle_control_deck = c_err_preset_element
      RETURN
    ENDIF
    control_block_done(elementselected) = .TRUE.
    handle_control_deck = c_err_none

    SELECT CASE (elementselected)
    CASE(1)
      nx_global = as_integer(value, handle_control_deck)
    CASE(2)
      ny_global = as_integer(value, handle_control_deck)
    CASE(3)
      nz_global = as_integer(value, handle_control_deck)
    CASE(c_ndims+1)
      x_min = as_real(value, handle_control_deck)
    CASE(c_ndims+2)
      x_max = as_real(value, handle_control_deck)
    CASE(c_ndims+3)
      y_min = as_real(value, handle_control_deck)
    CASE(c_ndims+4)
      y_max = as_real(value, handle_control_deck)
    CASE(c_ndims+5)
      z_min = as_real(value, handle_control_deck)
    CASE(c_ndims+6)
      z_max = as_real(value, handle_control_deck)
    CASE(3*c_ndims+1)
      nprocx = as_integer(value, handle_control_deck)
    CASE(3*c_ndims+2)
      nprocy = as_integer(value, handle_control_deck)
    CASE(3*c_ndims+3)
      nprocz = as_integer(value, handle_control_deck)
    CASE(4*c_ndims+1)
      npart_global = as_long_integer(value, handle_control_deck)
    CASE(4*c_ndims+2)
      nsteps = as_integer(value, handle_control_deck)
    CASE(4*c_ndims+3)
      t_end = as_real(value, handle_control_deck)
    CASE(4*c_ndims+4)
      dt_multiplier = as_real(value, handle_control_deck)
    CASE(4*c_ndims+5)
      dlb_threshold = as_real(value, handle_control_deck)
      dlb = .TRUE.
    CASE(4*c_ndims+6)
      IF (rank .EQ. 0) THEN
        DO io = stdout, du, du - stdout ! Print to stdout and to file
          WRITE(io,*) '*** ERROR ***'
          WRITE(io,*) 'The "icfile" option is no longer supported.'
          WRITE(io,*) 'Please use the "import" directive instead'
        ENDDO
      ENDIF
      CALL MPI_ABORT(MPI_COMM_WORLD, errcode, ierr)
    CASE(4*c_ndims+7)
      restart_snapshot = as_integer(value, handle_control_deck)
      ic_from_restart = .TRUE.
    CASE(4*c_ndims+8)
      neutral_background = as_logical(value, handle_control_deck)
    CASE(4*c_ndims+9)
      field_order = as_integer(value, handle_control_deck)
      IF (field_order .NE. 2 .AND. field_order .NE. 4 &
          .AND. field_order .NE. 6) THEN
        handle_control_deck = c_err_bad_value
      ELSE
        CALL set_field_order(field_order)
      ENDIF
    CASE(4*c_ndims+10)
      stdout_frequency = as_integer(value, handle_control_deck)
    CASE(4*c_ndims+11)
      use_random_seed = as_logical(value, handle_control_deck)
    END SELECT

  END FUNCTION handle_control_deck



  FUNCTION check_control_block()

    INTEGER :: check_control_block, index, io

    check_control_block = c_err_none

    ! nprocx/y/z and npart are optional
    control_block_done(3*c_ndims+1:4*c_ndims+1) = .TRUE.

    ! All entries after t_end are optional
    control_block_done(4*c_ndims+4:) = .TRUE.

    DO index = 1, control_block_elements
      IF (.NOT. control_block_done(index)) THEN
        IF (rank .EQ. 0) THEN
          DO io = stdout, du, du - stdout ! Print to stdout and to file
            WRITE(io,*)
            WRITE(io,*) '*** ERROR ***'
            WRITE(io,*) 'Required control block element ', &
                TRIM(ADJUSTL(control_block_name(index))), &
                ' absent. Please create this entry in the input deck'
          ENDDO
        ENDIF
        check_control_block = c_err_missing_elements
      ENDIF
    ENDDO

    IF (.NOT. neutral_background) THEN
      IF (rank .EQ. 0) THEN
        DO io = stdout, du, du - stdout ! Print to stdout and to file
          WRITE(io,*)
          WRITE(io,*) '*** ERROR ***'
          WRITE(io,*) 'The option "neutral_background=F" is not supported', &
              ' in this version of EPOCH.'
        ENDDO
      ENDIF
      check_control_block = c_err_terminate
    ENDIF

  END FUNCTION check_control_block

END MODULE deck_control_block
