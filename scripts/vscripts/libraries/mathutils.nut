
/* 
 * Math utilities for VScript, L4D2 edition
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
 *
 *
 *
 * To load the library, use IncludeScript() to add this script to the current script scope or the root scope:
 * IncludeScript("libraries/mathutils")
 * IncludeScript("libraries/mathutils", getroottable())
 *
 * To use the classes and functions, prefix them with MathUtils.
 */
 

 
if(!("MathUtils" in this) || ("VERSION" in MathUtils && MathUtils.VERSION < 1.0))
{
	this.MathUtils <- 
	{
		VERSION = 1.0
	}
	IncludeScript("libraries/misc_utils", this.MathUtils)
	IncludeScript("libraries/matrix", this.MathUtils)
}