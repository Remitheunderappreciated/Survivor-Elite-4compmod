
/* 
 * Math utilities - Misc. functions
 *
 * Copyright (c) 2019 Rectus
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
 



/* Returns 1 or -1 depending on the sign of the input.
 *
 */
function Sign(value)
{
	if(value > 0)
		return 1
	else
		return -1
}


/* Linear interpolation from a to b over [0, 1]
 *
 */
function Lerp(a, b, time)
{
	return a + time * (b - a)
}


/* Linear interpolation on vectors from a to b over [0, 1]
 *
 */
function VectorLerp(a, b, time)
{
	return Vector(Lerp(a.x, b.x, time), Lerp(a.y, b.y, time), Lerp(a.z, b.z, time))
}


/* Radians to degrees
 *
 */
function RadToDeg(angle)
{
	return angle * 180 / PI
}


/* Degrees to radians
 *
 */
function DegToRad(angle)
{
	return angle * PI / 180
}

	
/* Normalizes an angle in the range -180 to 180 degrees
 *
 */
function NormalizeAngle(angle)
{
	angle = angle % 360

	// If the angle is bigger than a half turn, turn it back a whole rotation.
	if(angle > 180)
		angle -= 360
	else if(angle < -180)
		angle += 360	
	
	return angle
}


/* Composes a QAngle from a forward and up vector.
 *
 */
function QAngleFromOrientation(forward, up)
{
	local yaw = RadToDeg(atan(forward.y/forward.x))
	
	if(forward.x < 0)
	{
		yaw += 180	
	}
	
	local pitch = -RadToDeg(atan(forward.z/forward.Length2D()))
	
	local rightHorizontal = Vector(-forward.y, forward.x, 0)
	local upright = forward.Cross(rightHorizontal)
	local roll = RadToDeg(atan2( rightHorizontal.Dot(up) / rightHorizontal.Length() ,
		upright.Dot(up) / upright.Length() ))
		
	return QAngle(pitch, yaw, roll)
}


/* Returns the orientation of a direction vector with an optional roll in degrees.
 *
 */
function QAngleFromVector(vector, roll = 0)
{
	if(vector.LengthSqr() == 0.0)
	{
		return QAngle(0, 0, roll)
	}  
	
	local yaw = RadToDeg(atan(vector.y/vector.x))
	local pitch = -RadToDeg(atan(vector.z/vector.Length2D()))
	
	if(vector.x < 0)
	{
		yaw += 180	
	}
   
	return QAngle(pitch, yaw, roll)
}


/* Checks angles for equality
 *
 */
function AreQAnglesEqual(a1, a2, precision = 0.001)
{
	local quat = QuaternionMultiply(a1.ToQuat(), a2.ToQuat().Invert())
	return quat.Dot(Quaternion(0,0,0,1)) >= 1 - precision
}


/* Multiplies two quaternions together (q1 * q2).
 *
 * This represents compositing, or adding the rotations together with q2 added after q1.
 */
function QuaternionMultiply(q1, q2)
{
	local w = q1.w * q2.w  -  q1.x * q2.x  -  q1.y * q2.y  -  q1.z * q2.z 
	local x = q1.w * q2.x  +  q1.x * q2.w  +  q1.y * q2.z  -  q1.z * q2.y 
	local y = q1.w * q2.y  -  q1.x * q2.z  +  q1.y * q2.w  +  q1.z * q2.x 
	local z = q1.w * q2.z  +  q1.x * q2.y  -  q1.y * q2.x  +  q1.z * q2.w
	
	return Quaternion(x, y, z, w)
}


/* Transforms an entity local vector to a world space vector.
 * 
 * Faster than using the transform matrix class, but doesn't handle scale.
 */
function TransformPosLocalToWorld(localVec, basisEnt)
{
	return basisEnt.GetOrigin() + RotatePosition(Vector(0, 0, 0), basisEnt.GetAngles(), localVec)
}




