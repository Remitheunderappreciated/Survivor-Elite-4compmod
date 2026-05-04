
/* 
 * Math utilities - Matrix classes
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
 


class Matrix {

	static MathUtils = this

	_values = []
	_rows = 0
	_cols = 0
	_det = null // cached determinant
	_inv = null //cached inverse
	
	
	/* Creates a numRows x numCols matrix from a set of values.
	 *
	 * Supports flat arrays ordered by rows, nested arrays, and arrays of Vector objects.
	 * 
	 * Throws an exeption on invalid input.
	 */
	constructor(values, numRows, numCols) {
	
		if(numRows < 1 || numCols < 1)
		{
			throw "Invalid matrix dimensions"
		}
		
		_rows = numRows
		_cols = numCols
	
		local numVals = numRows * numCols
	
		switch(typeof values)
		{
			case "array":	// Either a flat array or one filled with other structures
			
				_values = _parseArrayValues(values, numVals)
			
				return
			
			default:
			
				throw "Matrix values of type " + typeof values + " not supported"
		}
	}
	
	
	function GetValuesFlatArray()
	{
		return _values
	}
	
	
	function GetNumRows()
	{
		return _rows
	}
	
	
	function GetNumColumns()
	{
		return _cols
	}

	
	/* Returns the value in the specified cell.
	 *
	 * Throws an exeption on invalid input.
	 */
	function GetCellValue(row, col)
	{
		if(row < 0 || col < 0 || row >= _rows|| col >= _cols)
		{
			throw "Invalid cell"
		}
	
		return _values[col + (row * _cols)]
	}
	
	
	
	/* Returns the specified row as an array.
	 *
	 * Throws an exeption on invalid input.
	 */
	function GetRowArray(row)
	{
		if(row < 0 || row >= _rows)
		{
			throw "Invalid cell"
		}
	
		local start = row * _cols
		return _values.slice(start, start + _cols)
	}
	
	
	/* Returns the specified column as an array.
	 *
	 * Throws an exeption on invalid input.
	 */
	function GetColArray(col)
	{
		if(col < 0 || col >= _cols)
		{
			throw "Invalid cell"
		}
		
		local retval = []
		
		for(local i = 0; i < _rows; i++)
		{
			retval.append(this.GetCellValue(i, col))
		}
	
		return retval
	}
	
	
	/* Returns the specified cofactor.
	 *
	 * Throws an exeption on invalid input.
	 */
	function GetCofactor(row, col)
	{
		if(_rows <= 1 || _cols <= 1)
		{
			throw "Matrix too small to extract cofactor"
		}
	
		local vals = []
		
		for(local i = 0; i < _rows; i++)
		{
			for(local j = 0; j < _cols; j++)
			{
				if(i != row && j != col)
				{
					vals.append(this.GetCellValue(i, j))
				}
			}
		}
		
		return this.getclass()(vals, _rows - 1, _cols - 1)
	}
	
	
	/* Returns the determinant for a square matrix.
	 *
	 * Throws an exeption on non square matrices.
	 */
	function GetDeterminant()
	{
		if(_det) {return _det}
		
		if(_rows != _cols) {throw("No determinant for non-square matrix")}
		
		switch(_rows)
		{
			case 1:
				_det = _values[0]
				return _det
				
			case 2:
				_det = (_values[0] * _values[3]) - (_values[1] * _values[2])
				return _det	
			
			default:	
				_det = 0
				local sign = 1
				
				for(local i = 0; i < _cols; i++)
				{
					local cf = this.GetCofactor(0, i)
					_det += sign * this.GetCellValue(0, i) * cf.GetDeterminant()
					sign = -sign
				}
			
				return _det
		}
		
	}
	
	
	/* Returns the transpose of the matrix.
	 *
	 */
	function GetTranspose()
	{
		local vals = []
		for(local i = 0; i < _cols; i++)
		{
			vals.append(this.GetColArray(i))
		}
		
		return this.getclass()(vals, _cols, _rows)
	}
	
	
	/* Returns the adjunct for a square matrix.
	 *
	 * Throws an exeption on non square matrices.
	 */
	function GetAdjunct()
	{	
		if(_rows != _cols) {throw("No adjunct for non-square matrix")}
		
		local vals = []
		
		for(local i = 0; i < _rows; i++)
		{
			for(local j = 0; j < _cols; j++)
			{
				local cf = this.GetCofactor(i, j)
				local sign = ((i + j) % 2 == 0)? 1 : -1
				vals.append(sign * cf.GetDeterminant())
			}
		}
		
		return this.getclass()(vals, _rows, _cols).GetTranspose()
	}
	
	
	/* Returns the inverse for a square matrix.
	 *
	 * Throws an exeption on non-invertible matrices.
	 */
	function GetInverse()
	{
		if(_inv) {return _inv}
		
		if(_rows != _cols) {throw("No inverse for non-square matrix")}
		
		local det = this.GetDeterminant()
		
		if(det == 0) {throw("Singular matrix")}
		
		local adj = this.GetAdjunct()
		
		local vals = []
		
		for(local i = 0; i < _rows; i++)
		{
			for(local j = 0; j < _cols; j++)
			{
				vals.append(adj.GetCellValue(i, j) / det.tofloat())
			}
		}
		
		_inv = this.getclass()(vals, _rows, _cols)
		_inv._inv = this.weakref()
		return _inv
	}
	
	
	/* Overloaded multiplication. Does matrix multiplication, 
	 * linear transforms with vectors and arrays and scalar multiplication with other values.
	 */
	function _mul(other)
	{
		return _basemul(other)
	}

	
	
	/* Overloaded string conversion
	 */
	function _tostring()
	{
		local retval = ""
		
		for(local i = 0; i < _rows; i++)
		{
			for(local j = 0; j < _cols; j++)
			{
				retval += this.GetCellValue(i, j) + " "
			}
			retval += "\n"
		}
		return retval
	}
	
	
	/* Private functions */
		
	
	function _basemul(other)
	{
		switch(typeof other)
		{
			case "instance":
			
				if(other.getclass() != this.getclass()) {throw("Unknown class for matrix multiplication")}
			
				if(other.GetNumRows() != _cols) {throw("Invalid matrix dimensions for multiplication")}
				
				local newVals = []
				
				
				for(local j = 0; j < _rows; j++)
				{
					for(local i = 0; i < other.GetNumColumns(); i++)
					{
						local cellVal = 0
					
						for(local k = 0; k < _cols; k++)
						{
							cellVal += this.GetCellValue(j, k) * other.GetCellValue(k, i)
						}
						
						newVals.append(cellVal)
					}
				}
				
				return this.getclass()(newVals, _rows, other.GetNumColumns())
			
			
			case "array":
			
				if(other.len() != _cols)
				{throw("Invalid vector dimensions for multiplication")}
				
				local newVals = []
				
				
				for(local j = 0; j < _rows; j++)
				{
					local cellVal = 0
				
					for(local k = 0; k < _cols; k++)
					{
						cellVal += this.GetCellValue(j, k) * other[k]
					}
					
					newVals.append(cellVal)
				}

				
				return newVals
				
			case "Vector":
			
				if(_cols != 3) {throw("Invalid vector dimensions for multiplication")}
				
				local newVals = []
				
				
				for(local j = 0; j < _rows; j++)
				{	
					local cellVal = this.GetCellValue(j, 0) * other.x
					cellVal += this.GetCellValue(j, 1) * other.y
					cellVal += this.GetCellValue(j, 2) * other.z
					
					newVals.append(cellVal)
				}

				
				return Vector(newVals[0], newVals[1], newVals[2])
			
			
			default:
				// Assuming scalar values for unknown types
				local newVals = []
				foreach(val in _values)
				{
					newVals.append(val * other)
				}
				return this.getclass()(newVals, _rows, _cols)
				
		}
	}
	
	
	function _parseArrayValues(values, numVals)
	{
		switch(typeof values[0])
		{
			case "array":	// Nested arrays of individual rows.
			
				if(values.len() != _rows) {throw "Invalid amount of rows"}
				
				local outVals = []
				
				// Recursively parse inner arrays
				foreach(row in values)
				{
					outVals.extend(_parseArrayValues(row, _cols))
				}
			
				return outVals
				
				
			case "Vector":
			
				if(values.len() != _rows) {throw "Invalid amount of rows"}
				
				local outVals = []
				
				// Recursively parse inner arrays
				foreach(row in values)
				{
					outVals.extend([row.x, row.y, row.z])
				}
				
				return outVals
				
			
			case "integer":	// Flat array of integers or floats
			case "float":
				
				if(values.len() != numVals) {throw "Invalid array length"}
						
				return clone values
			
			default:
			
				throw "Matrix inner values of type " + typeof values[0] + " not supported"
		}
	
	}
}


/* Represents a transformation, or mapping between different coordinate systems.
 * 
 * Passing an entity to the constructor uses the entitys location, rotation and scale to 
 * generate a transformation from its local space to the world space or its parents space if parented.
 * Scale is only supported for model entities.
 *
 * Multiplying a TransformMatrix with a Vector or QAngle as the right hand operand transforms them
 * between the coordinate systems.
 */
class TransformMatrix extends Matrix {

	/* Creates a 4 x 4 transformation matrix.
	 *
	 * Valid call formats are:
	 *
	 * TransformMatrix(array [16]) - Pass matrix cell values as an array.
	 * TransformMatrix(CBaseEntity entity) - Creates a matrix of the transform of the specified entity.
	 * TransformMatrix(Vector location, QAngle rotation, Vector scale) - Creates a matrix from the specified transform.
	 */
	constructor(...)
	{
		if(vargv.len() < 1) {throw("Too few parameters in constructor")}
		
		local values = []
	
		switch(typeof vargv[0])
		{
			case "array":

				if(vargv.len() == 3)
				{
					return base.constructor(vargv[0], vargv[1], vargv[2])
				}
				
				return base.constructor(vargv[0], 4, 4)
				
			case "instance":
			
				local ent = vargv[0]
			
				if("GetClassname" in ent) // Check that we have a game entity
				{
					local loc = ent.GetOrigin()
					local rot = ent.GetAngles()
					local scale = 1.0
					if(NetProps.HasProp(ent, "m_flModelScale"))
						{scale = NetProps.GetPropFloat(ent, "m_flModelScale")}
						
					values = this._TransformFromLocRotScale(loc, rot, Vector(scale, scale, scale))
				
					return base.constructor(values, 4, 4)
				}
				
			case "Vector": 
			
				local loc = vargv[0]
				local rot = QAngle(0,0,0)
				local scale = Vector(1, 1, 1)
				
				if(vargv.len() >= 2)
				{
					if(typeof vargv[1] != "QAngle") {throw("Expected QAngle on parameter 2")}
					rot = vargv[1]
				}
				if(vargv.len() >= 3) 
				{
					if(typeof vargv[2] != "Vector") {throw("Expected Vector on parameter 3")}
					scale = vargv[2]
				}

				values = this._TransformFromLocRotScale(loc, rot, scale)
			
				return base.constructor(values, 4, 4)
			
				
			default:
				{throw("Unknown parameter in constructor")}
		}
	
		
	}
	

	/* Returns the inverse of the transformation.
	 * This can be used to get a world space to local space mapping.
	 */
	function GetInverse()
	{
		if(_inv) {return _inv}
		
		local det = this.GetDeterminant()
		
		if(det == 0) {throw("Singular matrix")}
		
		local adj = this.GetAdjunct()
		
		local vals = []
		
		for(local i = 0; i < _rows; i++)
		{
			for(local j = 0; j < _cols; j++)
			{
				vals.append(adj.GetCellValue(i, j) / det.tofloat())
			}
		}

		_inv = this.getclass()(vals)
		return _inv
	}
	
	
	/* Returns the orienation of this transform as a QAngle
	 *
	 */
	function GetOrientation()
	{
		local fwd = this.TransformDirection(Vector(1, 0, 0))
		local up = this.TransformDirection(Vector(0, 0, 1))
		
		return MathUtils.QAngleFromOrientation(fwd, up)
	}
	
	
	/* Transforms an orientation QAngle
	 *
	 */
	function TransformOrientation(orientation)
	{
		return RotateOrientation(this.GetOrientation(), orientation)
	}
	
	
	/* Transforms a direction Vector
	 *
	 */
	function TransformDirection(direction)
	{
		return this._DoMultiply(direction, 0.0)
	}
	
	
	/* Transforms a position Vector
	 *
	 * The same function as multiplying the matrix with a vector.
	 */
	function TransformPosition(position)
	{
		return this._DoMultiply(position, 1.0)
	}


	/* Overloaded multiplication. Does matrix multiplication, 
	 * linear transforms with vectors and arrays and scalar multiplication with other values.
	 *
	 * Multiplying a local space position vector transforms it into world space.
	 */
	function _mul(other)
	{
		return this._DoMultiply(other, 1.0)
	}
	
	/* Private functions */

	// w is the fourth component of a coordinate, set to 1.0 to enable translation or 0.0 to disable.
	function _DoMultiply(other, w)
	{
		switch(typeof other)
		{
			case "Vector": // Transforms a 3D Vector object.
				local values = [other.x, other.y, other.z, w]
				
				local retArray = this._basemul(values)
				
				return Vector(retArray[0], retArray[1], retArray[2])
				
			case "array":
				if(other.len() == 3)
				{
					local values = clone other
					values.append(w)
					
					local retArray = this._basemul(values)
					retArray.remove(3)
					return retArray
				}
				//else fallthrough to default
			
			default:
				return this._basemul(other)
		}
	}
	
		
	function _TransformFromLocRotScale(loc, rot, scale)
	{
		local roll = rot.z * PI / 180
		local pitch = rot.x * PI / 180
		local yaw = rot.y * PI / 180
	
		local Rz = base([ // Roll
			[1.0, 	0, 			0, 				0],  
			[0, 	cos(roll), 	-sin(roll), 	0], 
			[0, 	sin(roll), 	cos(roll) ,		0], 
			[0, 	0, 			0, 				1.0] ], 4, 4)
			
		local Rx = base([ // Pitch
			[cos(pitch), 	0, 		sin(pitch), 0],  
			[0, 			1.0, 	0, 			0], 
			[-sin(pitch), 	0, 		cos(pitch), 0], 
			[0, 			0, 		0, 			1.0] ], 4, 4)
			
		local Ry = base([ //Yaw
			[cos(yaw), 		-sin(yaw), 	0, 		0],  
			[sin(yaw), 		cos(yaw), 	0, 		0], 
			[0, 			0, 			1.0, 	0], 
			[0, 			0, 			0, 		1.0] ], 4, 4)
	
		local scaleMat = base([ 
			[scale.x, 	0, 			0, 			0],  
			[0, 		scale.y, 	0, 			0], 
			[0, 		0,			scale.z, 	0], 
			[0, 		0, 			0, 			1.0] ], 4, 4)
			
		local locMat = base([ 
			[1.0, 0, 0, loc.x	],  
			[0, 1.0, 0, loc.y	], 
			[0, 0, 1.0, loc.z	], 
			[0, 0, 0, 	1.0		] ], 4, 4)
	
		local rotMat = Ry * Rx * Rz // The correct rotation order for Source angles seems to be Roll, Pitch, Yaw
		local result = locMat * rotMat * scaleMat
		
		return result.GetValuesFlatArray()
	}

}



