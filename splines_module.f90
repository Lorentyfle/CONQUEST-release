! $Id$
! -----------------------------------------------------------
! Module splines
! -----------------------------------------------------------
! Code area 9: general
! -----------------------------------------------------------

!!****h* Conquest/spline_module
!!  NAME
!! 
!!  PURPOSE
!! 
!!  AUTHOR
!!   D.R.Bowler
!!  CREATION DATE
!!   23/05/01
!!  MODIFICATION HISTORY
!!   31/05/2001 dave
!!    Added RCS Id tag to header, increased ROBODoc documentation
!!   20/06/2001 dave
!!    Added RCS Log tag and cq_abort
!!   15:48, 08/04/2003 drb 
!!    Bug fixes in splint and dsplint
!!   2019/08/14 16:37 dave
!!    Replacing NR routines
!!***
module splines
  
  use global_module, only: area_general

  implicit none

  ! RCS tag for object file identification 
  character(len=80), save, private :: RCSid = "$Id$"

contains
  
! -----------------------------------------------------------
! Subroutine spline
! -----------------------------------------------------------

!!****f* splines/spline *
!!
!!  NAME 
!!   spline
!!  USAGE
!! 
!!  PURPOSE
!!   Given an array y(1:n) containing a function tabulated at 
!!   REGULAR intervals with spacing delta_x, and given values
!!   dy1 and dyn for the first derivative of the function at 
!!   the end points, this subroutine returns an array d2y(1:n) 
!!   containing the second derivatives of the interpolating 
!!   function at the tabulated points. If dy1 and/or dyn are 
!!   equal or larger than BIG, the routine is signaled to set 
!!   the corresponding boundary condition for a natural spline, 
!!   with zero second derivative at that point.
!!
!!   Uses LAPACK dptsv to solve symmetric tridiagonal linear equation
!!  INPUTS
!!   integer :: n - size of table to be splined
!!   real(double) :: delta_x - spacing of values in table
!!   real(double) :: dy1, dyn - end points giving boundaries
!!   real(double), dimension(n) :: y, d2y - table and second derivative
!!  USES
!!   datatypes, numbers
!!  AUTHOR
!!   D. R. Bowler
!!  CREATION DATE
!!   2019/08/13
!!  MODIFICATION HISTORY
!!  SOURCE
  subroutine spline( n, delta_x, y, dy1, dyn, d2y )

    use datatypes
    use numbers
    use GenComms, only: cq_abort
    use memory_module, only: reg_alloc_mem, reg_dealloc_mem, type_dbl

    implicit none

    ! Passed variables
    integer :: n

    real(double) :: delta_x, dy1, dyn
    real(double), dimension(n) :: y, d2y

    ! Local variables
    integer :: i, k, stat, info
    real(double), dimension(:), allocatable :: b, d, du
    external :: dptsv

    allocate(b(n), d(n), du(n-1),STAT=stat)
    if (stat /= 0) call cq_abort("spline: Error alloc mem: ", n)
    call reg_alloc_mem(area_general, 3*n, type_dbl)

    b = zero
    ! Diagonal (d) and sub-diagonal (du) entries in matrix
    d = four
    du = one

    ! Now set up RHS of linear equation
    if (dy1 > BIG) then ! lower boundary condition set to 'natural'
       b(1) = zero
       b(n) = zero
    else ! or else to have a specified first derivative: 'clamped'
       b(1) = (six/delta_x) * ((y(2) - y(1))/delta_x - dy1 )
       b(n) = (six/delta_x) * (dyn - (y(n) - y(n-1))/delta_x )
       d(1) = two
       d(n) = two
    end if
    do i = 2, n-1
       b(i) = six*(y(i-1) - two*y(i) + y(i+1))/(delta_x * delta_x)
    end do
    ! Solution of A.x = b is returned in b
    call dptsv(n, 1, d, du, b, n, info)
    if(info/=0) call cq_abort("spline: error in dptsv, info is ",info)
    d2y = b
    if(dy1 > BIG) then
       d2y(1) = zero
       d2y(n) = zero
    end if
    deallocate(d,b,du)
    return
  end subroutine spline
!!***

! -----------------------------------------------------------
! Subroutine spline_nonU
! -----------------------------------------------------------

!!****f* splines/spline_nonU *
!!
!!  NAME 
!!   spline_nonU - makes a spline table for non-uniform x array
!!  USAGE
!!   spline_nonU(n, x, y, dy1, dyn, d2y)
!!  PURPOSE
!!   Given an array y(1:n) containing a function tabulated at 
!!   IRREGULAR intervals given by array x(1:n), and given values
!!   yp1 and ypn for the first derivative of the function at 
!!   the end points, this subroutine returns an array d2y(1:n) 
!!   containing the second derivatives of the interpolating 
!!   function at the tabulated points. If dy1 and/or dyn are 
!!   equal or larger than BIG, the routine is signaled to set 
!!   the corresponding boundary condition for a natural spline, 
!!   with zero second derivative at that point.
!!   
!!   Uses LAPACK dgtsv to solve general tridiagonal linear equation
!!  INPUTS
!! 
!! 
!!  USES
!! 
!!  AUTHOR
!!   D.R.Bowler
!!  CREATION DATE
!!   2019/08/15
!!  MODIFICATION HISTORY
!!  SOURCE
!!
  subroutine spline_nonU( n, x, y, dy1, dyn, d2y )

    use datatypes
    use numbers
    use GenComms, only: cq_abort
    use memory_module, only: reg_alloc_mem, reg_dealloc_mem, type_dbl

    implicit none

    ! Passed variables
    integer :: n

    real(double) :: dy1, dyn
    real(double), dimension(n) :: x, y, d2y

    ! Local variables
    integer :: i, k, stat, info
    real(double), dimension(:), allocatable :: b, d, du, dl
    external :: dgtsv

    allocate(b(n), d(n), dl(n-1), du(n-1),STAT=stat)
    if (stat /= 0) call cq_abort("spline: Error alloc mem: ", n)
    call reg_alloc_mem(area_general, 3*n, type_dbl)

    b = zero

    ! Now set up RHS of linear equation
    if (dy1 > BIG) then ! lower boundary condition set to 'natural'
       b(1) = zero
       b(n) = zero
       d(1) = four*(x(2) - x(1))
       d(n) = four*(x(n) - x(n-1))
    else ! or else to have a specified first derivative: 'clamped'
       b(1) = six * ( (y(2) - y(1))/(x(2) - x(1)) - dy1 )
       b(n) = six * ( dyn - (y(n) - y(n-1))/(x(n) - x(n-1)) )
       d(1) = two*(x(2) - x(1))
       d(n) = two*(x(n) - x(n-1))
    end if
    do i = 2, n-1
       dl(i-1) = x(i) - x(i-1)
       d(i)  = two * ( x(i+1) - x(i-1) )
       du(i) = x(i+1) - x(i)
       b(i)  = six*(y(i-1) - y(i))/(x(i) - x(i-1)) + &
            six*(y(i+1) - y(i))/(x(i+1) - x(i))
    end do
    du(1) = x(2) - x(1)
    dl(n-1) = x(n) - x(n-1)
    ! Solution of A.x = b is returned in b
    call dgtsv(n, 1, dl, d, du, b, n, info)
    if(info/=0) call cq_abort("spline: error in dgtsv, info is ",info)
    d2y = b
    if(dy1 > BIG) then
       d2y(1) = zero
       d2y(n) = zero
    end if
    deallocate(d,b,du)
    return
  end subroutine spline_nonU
!!***


! -----------------------------------------------------------
! Subroutine dsplint
! -----------------------------------------------------------

!!****f* splines/dsplint *
!!
!!  NAME 
!!   dsplint
!!  USAGE
!!   dsplint(xarray, yarray, d2y/dx2 array, size of array, x value, dy)
!!   dsplint(xa,ya,y2a,n,x,dy)
!!  PURPOSE
!!   NR routine for interpolation using spline table set up by spline
!!   Takes a spline table with uniform x spacing delta_x and, for the 
!!   specified value x, finds the derivative value.
!!  INPUTS
!!   integer :: n (size of table)
!!   real(double) :: x, y, delta_x (x value specified, y value to be found, x-value spacing)
!!   real(double), dimension(n) :: ya, y2a (y, d2y/dx2 arrays)
!!   logical :: flag (flag to warn if given x is out of tabulated range)
!!  USES
!!   datatypes, numbers, GenComms
!!  AUTHOR
!!   D.R.Bowler
!!  CREATION DATE
!!   07:50, 2003/03/19 dave
!!  MODIFICATION HISTORY
!!   15:47, 08/04/2003 drb 
!!    Fixed major bug: array references were all one element off (carried over from splint)
!!   11:04, 03/09/2003 drb 
!!    Added xlo/xhi correction that was added to splint (should have been done earlier !)
!!   08:56, 2003/11/20 dave
!!    Added return to prevent array overrun
!!   08:01, 2003/12/04 dave
!!    Added return of spline-interpolated value as well as derivative
!!   25/01/2019 tsuyoshi
!!    added RD_ERR term for the round-error problem
!!  SOURCE
!!
  subroutine dsplint(delta_x,ya,y2a,n,x,y,dy,flag)

    use datatypes
    use numbers
    use GenComms, ONLY: cq_abort

    ! Passed variables
    integer, intent(in) :: n
    real(double), intent(in) :: x
    real(double), intent(out) :: y,dy
    real(double), intent(in) :: delta_x
    real(double), dimension(n), intent(in) :: y2a,ya
    logical, intent(out) :: flag

    ! Local variables
    integer :: khi,klo
    real(double) :: a,b,da,db,dc,dd, xlo, xhi

    ! initialize warning flag
    flag = .false.
    !ORI if (x>(n-1)*delta_x.OR.x<0) then
    if (x>(n-1)*delta_x+RD_ERR.OR.x<-RD_ERR) then
       flag = .true. ! the given x lies outside the tabulated values, warn the calling routine
       y = 0.0_double
       dy = 0.0_double ! Avoid array overruns
       return
    end if

    ! bracket x value   
    klo = aint(x/delta_x) + 1 ! integer division gives lower bound, add 1 for array value
    khi = klo + 1
    ! Remember that we added to get array value and subtract it off again !
    xlo =delta_x*real(klo-1,double)
    xhi =delta_x*real(khi-1,double)

    !2019/Jan/29 TM
     if(klo == n) then
       y = 0.0_double
       dy = 0.0_double ! Avoid array overruns
       return
     endif
    !2019/Jan/29 TM

    ! Create value of y
    a = (xhi-x)/delta_x
    b = (x-xlo)/delta_x
    da = -one/delta_x
    db =  one/delta_x
    dc = -delta_x*(three*a*a-one)/six
    dd =  delta_x*(three*b*b-one)/six
    y=a*ya(klo)+b*ya(khi)+ &
         ( (a*a*a-a)*y2a(klo)+(b*b*b-b)*y2a(khi) )*(delta_x*delta_x)/six
    dy =  da*ya(klo)+db*ya(khi)+dc*y2a(klo)+dd*y2a(khi)
    return
  end subroutine dsplint
!!***

end module splines



