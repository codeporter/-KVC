//
//  NSObject+JKKVC.m
//  仿写kvc
//
//  Created by coder on 2019/10/9.
//  Copyright © 2019 coder. All rights reserved.
//

#import "NSObject+JKKVC.h"

#import <objc/runtime.h>

@interface _TrunkObject : NSObject

@property (nonatomic, assign) Ivar *ivarList;
@property (nonatomic, assign) unsigned int count;

@end

@implementation _TrunkObject

- (void)dealloc {
    if (_ivarList) {
        free(_ivarList);
        _ivarList = nil;
    }
}

@end

@interface NSObject ()

@property (nonatomic, strong) _TrunkObject *trunk;

@end

@implementation NSObject (JKKVC)


+ (BOOL)jk_accessInstanceVariablesDirectly {
    return YES;
}

/** valueForKey查找过程：假设传入的key为@"name"
 1、首先查看是否有getName,name,isName,_name方法，如果有直接通过对应的方法获取返回值，如果返回值是标量类型(int,float等)，包装成NSNumber或者NSValue类型；如果没找到方法跳到第2步。
 2、判断是否开启jk_accessInstanceVariablesDirectly，如果为YES，进入第3步；否则进入第4步
 3、查找是否有_name,_isName,name,isName 成员变量，如果有则通过对象的地址+成员变量的偏移量获取对应的数据，同样将标量类型进行包装；如果没有找到成员变量进入第三步。
 4、调用valueForUndefinedKey:来抛出异常。
*/
- (id)jk_valueForKey:(NSString *)key {
    if (!key || key.length <= 0) {
        [self valueForUndefinedKey:key];
    }
    
    NSString *upperFirsetCharKey = [NSString stringWithFormat:@"%@%@",[[key substringWithRange:NSMakeRange(0, 1)] uppercaseString], [key substringWithRange:NSMakeRange(1, key.length - 1)]];
    
    id obj;
    #define PerformGetterMethod(m) obj = _toggleGetterMethod(self, m, key);\
    if (obj) {\
        return obj;\
    }
    
    // getMethod = get<Key>;
    NSString *getMethod = [NSString stringWithFormat:@"get%@",upperFirsetCharKey];
    PerformGetterMethod(getMethod);
    
    // getMethod = key
    getMethod = key;
    PerformGetterMethod(getMethod);
    
    // getMethod = is<Key>
    getMethod = [NSString stringWithFormat:@"is%@",upperFirsetCharKey];
    PerformGetterMethod(getMethod);

    // getMethod = _<key>
    getMethod = [NSString stringWithFormat:@"_%@",key];
    PerformGetterMethod(getMethod);

    //仿照系统的KVC中，会判断accessInstanceVariablesDirectly
    Class cls = [self class];
    if ([cls jk_accessInstanceVariablesDirectly] == NO) {
        [self valueForUndefinedKey:key];
    }
    
    return _getValFromVariable(self, key);
}

/** setValue:ForKey:过程：假设传入的key为@"name"
 1、首先查看是否有setName:,_setName:方法，如果有直接通过对应的方法赋值，如果成员变量是标量类型(int,float等)，则将传入的参数value解包成对应类型数据；如果没找到方法跳到第2步。
 2、判断是否开启jk_accessInstanceVariablesDirectly，如果为YES，进入第3步；否则进入第4步
 3、查找是否有_name,_isName,name,isName成员变量，如果有则通过对象的地址+成员变量的偏移量获取成员变量的地址，同样将参数value解包成对应数据类型；如果没有找到成员变量进入第4步。
 4、调用setValue:forUndefinedKey:来抛出异常。
*/
- (void)jk_setValue:(id)value forKey:(NSString *)key {
    if (!key || key.length <= 0) {
        [self setValue:value forUndefinedKey:key];
    }
    
    NSString *upperFirsetCharKey = [NSString stringWithFormat:@"%@%@",[[key substringWithRange:NSMakeRange(0, 1)] uppercaseString], [key substringWithRange:NSMakeRange(1, key.length - 1)]];
    
    //setterMethod = set<Key>:
    NSString *setterMethod = [NSString stringWithFormat:@"set%@:",upperFirsetCharKey];
    if(_toggleSetterMethod(self, setterMethod, key, value)) {
        return;
    }
    //setterMethod = _set<Key>:
    setterMethod = [NSString stringWithFormat:@"_set%@:",upperFirsetCharKey];
    if (_toggleSetterMethod(self, setterMethod, key, value)) {
        return;
    }
    
    //仿照系统的KVC中，会判断accessInstanceVariablesDirectly
    Class cls = [self class];
    if ([cls accessInstanceVariablesDirectly] == NO) {
        [self setValue:value forUndefinedKey:key];
    }
    
    if(_setValForVariable(self, key, value) == NO) {
        [self setValue:value forUndefinedKey:key];
    }
}


- (id)jk_valueForKeyPath:(NSString *)keyPath {
    NSArray *array = [keyPath componentsSeparatedByString:@"."];
    
    if (array.count <= 0) {
        [self valueForUndefinedKey:keyPath];
    }
    
    id obj = self;
    for (int i = 0; i < array.count; i++) {
        NSString *key = array[i];
        obj = [obj jk_valueForKey:key];
    }
    return obj;
}
- (void)jk_setValue:(id)value forKeyPath:(NSString *)keyPath {
    NSArray *array = [keyPath componentsSeparatedByString:@"."];
    
    if (array.count <= 0) {
        [self setValue:value forUndefinedKey:keyPath];
    }
    
    id obj = self;
    for (int i = 0; i < array.count; i++) {
        NSString *key = array[i];
        if (i < array.count - 1) {
            obj = [obj jk_valueForKey:key];
        } else {
            [obj jk_setValue:value forKey:key];
        }
    }
}
#pragma mark - AssociatedObject
- (_TrunkObject *)trunk {
    _TrunkObject *obj = objc_getAssociatedObject(self, _cmd);
    if (obj == nil) {
        obj = [_TrunkObject new];
        objc_setAssociatedObject(self, _cmd, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return obj;
}

#pragma mark - pravite method

id _toggleGetterMethod(id self, NSString *methodName, NSString *key) {
    SEL selector = NSSelectorFromString(methodName);
    if ([self respondsToSelector:selector]) {
        NSMethodSignature *sign = [self methodSignatureForSelector:selector];
        const char *returnType = sign.methodReturnType;
        char type = returnType[0];
        IMP imp = [self methodForSelector:selector];
        switch (type) {
            case 'B': { //BOOL
                return @(((BOOL(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'c': { //char
                return @(((char(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'C': { //unsigned char
                return @(((unsigned char(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 's': { //short
                return @(((short(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'S': { //unsigned short
                return @(((unsigned short(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'i': { //int
                return @(((int(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'I': { //unsigned int
                return @(((unsigned int(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'l': { //long
                return @(((long(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'L': { //unsigned long
                return @(((unsigned long(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'q': { //long long
                return @(((long long(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'Q': { //unsigned long long
                return @(((unsigned long long(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'f': { //float
                return @(((float(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'd': { //double
                return @(((double(*)(id,SEL))imp)(self,selector));
                break;
            };
            case 'D': { //long double
                //系统的kvc中不支持long double类型
                [self valueForUndefinedKey:key];
                break;
            }
            case '@': { //id
                return ((id(*)(id,SEL))imp)(self,selector);
                break;
            };
            case '#': { //Class
                return ((Class(*)(id,SEL))imp)(self,selector);
                break;
            };
            case '*': { // char *
                //系统的kvc不支持char*
                [self valueForUndefinedKey:key];
                break;
            }
            case '^':{ //pointer
                //系统的kvc不支持pointer
                [self valueForUndefinedKey:key];
                break;
            }
            case '{': { //结构体
                NSUInteger size = 0;
                NSGetSizeAndAlignment(returnType, &size, nil);
                Byte buffer[size];
                
                //系统KVC内部也是用NSInvocation调用get方法取值
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sign];
                invocation.target = self;
                invocation.selector = selector;
                [invocation invoke];
                [invocation getReturnValue:buffer];
                
                return [NSValue valueWithBytes:buffer objCType:returnType];
                break;
            };
            case '(': { //联合体
                //系统的kvc不支持联合体
                [self valueForUndefinedKey:key];
                break;
            };
            case '[': {// c数组
                //系统的kvc中不支持c数组
                [self valueForUndefinedKey:key];
                break;
            }
            default: { // unknown
                [self valueForUndefinedKey:key];
                break;
            };
        }
    }
    return nil;
}

id _getValFromVariable(NSObject *self, NSString *key) {
    //首字母大写
    NSString *upperFirsetCharKey = [NSString stringWithFormat:@"%@%@",[[key substringWithRange:NSMakeRange(0, 1)] uppercaseString], [key substringWithRange:NSMakeRange(1, key.length - 1)]];
    
    unsigned int count = self.trunk.count;
    Ivar *ivarList = self.trunk.ivarList;
    if(ivarList ==  nil) {
        ivarList = class_copyIvarList([self class], &count);
        self.trunk.ivarList = ivarList;
        self.trunk.count = count;
    }
    
    NSString *_key = [NSString stringWithFormat:@"_%@", key];
    NSString *isKey = [NSString stringWithFormat:@"is%@", upperFirsetCharKey];
    NSString *_isKey = [NSString stringWithFormat:@"_%@", isKey];
    Ivar foundedIvar = nil;
    
    for (int i = 0; i < count; i++) {
        Ivar ivar = ivarList[i];
        NSString *ivarName = @(ivar_getName(ivar));
        
        if ([ivarName isEqualToString:_key] || [ivarName isEqualToString:_isKey]  || [ivarName isEqualToString:key] || [ivarName isEqualToString:isKey]) {
            foundedIvar = ivar;
            break;
        }
    }
    
    if (foundedIvar) {
        uintptr_t offset = ivar_getOffset(foundedIvar);
        const char *typeEncoding = ivar_getTypeEncoding(foundedIvar);
        char type = typeEncoding[0];
        
        void *ivarPtr = (__bridge void *)self + offset;
        switch (type) {
            case 'B': { //BOOL
                BOOL *val = (BOOL *)ivarPtr;
                return @(*val);
                break;
            };
            case 'c': { //char
                char *val = (char *)ivarPtr;
                return @(*val);
                break;
            };
            case 'C': { //unsigned char
                unsigned char *val = (unsigned char *)ivarPtr;
                return @(*val);
                break;
            };
            case 's': { //short
                short *val = (short *)ivarPtr;
                return @(*val);
                break;
            };
            case 'S': { //unsigned short
                unsigned short *val = (unsigned short *)ivarPtr;
                return @(*val);
                break;
            };
            case 'i': { //int
                int *val = (int *)ivarPtr;
                return @(*val);
                break;
            };
            case 'I': { //unsigned int
                unsigned int *val = ivarPtr;
                return @(*val);
                break;
            };
            case 'l': { //long
                long *val = (long *)ivarPtr;
                return @(*val);
                break;
            };
            case 'L': { //unsigned long
                unsigned long *val = (unsigned long *)ivarPtr;
                return @(*val);
                break;
            };
            case 'q': { //long long
                long long *val = (long long *)ivarPtr;
                return @(*val);
                break;
            };
            case 'Q': { //unsigned long long
                unsigned long long *val = (unsigned long long *)ivarPtr;
                return @(*val);
                break;
            };
            case 'f': { //float
                float *val = (float *)ivarPtr;
                return @(*val);
                break;
            };
            case 'd': { //double
                double *val = (double *)ivarPtr;
                return @(*val);
                break;
            };
            case 'D': { //long double
                //系统的kvc中不支持long double类型
                [self valueForUndefinedKey:key];
                break;
            }
            case '@': { //id
                __strong id *val = (__strong id *)ivarPtr;
                return *val;
                break;
            };
            case '#': { //Class
                __strong Class *val = (__strong Class *)ivarPtr;
                return *val;
                break;
            };
            case '*': { // char *
                //系统的kvc中不支持char *
                [self valueForUndefinedKey:key];
                break;
            }
            case '^':{ //pointer
                //系统的kvc中不支持pointer
                [self valueForUndefinedKey:key];
                break;
            }
            case '{': { //结构体
                NSUInteger size = 0;
                NSGetSizeAndAlignment(typeEncoding, &size, nil);
                Byte buffer[size];
                memcpy(buffer, ivarPtr, size);
                return [NSValue valueWithBytes:buffer objCType:typeEncoding];
                break;
            };
            case '(': { //联合体
                //系统的kvc中不支持结构体
                [self valueForUndefinedKey:key];
                break;
            };
            case '[': {// c数组
                //系统的kvc中不支持long double类型
                [self valueForUndefinedKey:key];
                break;
            }
            default: { // unknown
                [self valueForUndefinedKey:key];
                break;
            };
        }
    }
    return nil;
}

BOOL _toggleSetterMethod(id self, NSString *methodName, NSString *key, id value) {
    SEL selector = NSSelectorFromString(methodName);
    if ([self respondsToSelector:selector]) {
        NSMethodSignature *sign = [self methodSignatureForSelector:selector];
        const char *paramType = [sign getArgumentTypeAtIndex:2];//获取参数类型
        char type = paramType[0];
        IMP imp = [self methodForSelector:selector];
        switch (type) {
            case 'B': { //BOOL
                ((void(*)(id,SEL,BOOL))imp)(self, selector, [value boolValue]);
                return YES;
                break;
            };
            case 'c': { //char
                ((void(*)(id,SEL,char))imp)(self, selector, [value charValue]);
                return YES;
                break;
            };
            case 'C': { //unsigned char
                ((void(*)(id,SEL,unsigned char))imp)(self, selector, [value unsignedCharValue]);
                return YES;
                break;
            };
            case 's': { //short
                ((void(*)(id,SEL,short))imp)(self, selector, [value shortValue]);
                return YES;
                break;
            };
            case 'S': { //unsigned short
                ((void(*)(id,SEL,unsigned short))imp)(self, selector, [value unsignedShortValue]);
                return YES;
                break;
            };
            case 'i': { //int
                ((void(*)(id,SEL,int))imp)(self, selector, [value intValue]);
                return YES;
                break;
            };
            case 'I': { //unsigned int
                ((void(*)(id,SEL,unsigned int))imp)(self, selector, [value unsignedIntValue]);
                return YES;
                break;
            };
            case 'l': { //long
                ((void(*)(id,SEL,long))imp)(self, selector, [value longValue]);
                return YES;
                break;
            };
            case 'L': { //unsigned long
                ((void(*)(id,SEL,unsigned long))imp)(self, selector, [value unsignedLongValue]);
                return YES;
                break;
            };
            case 'q': { //long long
                ((void(*)(id,SEL,long long))imp)(self, selector, [value longLongValue]);
                return YES;
                break;
            };
            case 'Q': { //unsigned long long
                ((void(*)(id,SEL,unsigned long long))imp)(self, selector, [value unsignedLongLongValue]);
                return YES;
                break;
            };
            case 'f': { //float
                ((void(*)(id,SEL,float))imp)(self, selector, [value floatValue]);
                return YES;
                break;
            };
            case 'd': { //double
                ((void(*)(id,SEL,double))imp)(self, selector, [value doubleValue]);
                return YES;
                break;
            };
            case 'D': { //long double
                //系统的kvc中不支持long double类型
                [self setValue:value forUndefinedKey:key];
                break;
            }
            case '@': { //id
                ((void(*)(id,SEL,id))imp)(self, selector, value);
                return YES;
                break;
            };
            case '#': { //Class
                ((void(*)(id,SEL,Class))imp)(self, selector, value);
                return YES;
                break;
            };
            case '*': { // char *
                //系统的kvc不支持char*
                [self setValue:value forUndefinedKey:key];
                break;
            }
            case '^':{ //pointer
                //系统的kvc不支持pointer
                [self setValue:value forUndefinedKey:key];
                break;
            }
            case '{': { //结构体
                if ([value isKindOfClass:[NSValue class]] == NO) {
                    NSException *exception = [NSException exceptionWithName:@"value类型错误" reason:@"对结构体类型使用jk_setValue:forKey:方法，请确保传入的value类型是NSValue" userInfo:nil];
                    [exception raise];
                }
                //系统KVC内部也是用NSInvocation调用set方法设值
                const char * objcType= [(NSValue *)value objCType];
                NSUInteger size = 0;
                NSGetSizeAndAlignment(objcType, &size, nil);
                Byte buffer[size];
                [(NSValue *)value getValue:buffer];
                
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sign];
                invocation.target = self;
                invocation.selector = selector;
                [invocation setArgument:buffer atIndex:2];
                [invocation invoke];
                
                return YES;
                break;
            };
            case '(': { //联合体
                //系统的kvc不支持联合体
                [self setValue:value forUndefinedKey:key];
                break;
            };
            case '[': {// c数组
                //系统的kvc中不支持c数组
                [self setValue:value forUndefinedKey:key];
                break;
            }
            default: { // unknown
                [self setValue:value forUndefinedKey:key];
                break;
            };
        }
    }
    
    return NO;
}

BOOL _setValForVariable(NSObject *self, NSString *key, id value) {
    NSString *upperFirsetCharKey = [NSString stringWithFormat:@"%@%@",[[key substringWithRange:NSMakeRange(0, 1)] uppercaseString], [key substringWithRange:NSMakeRange(1, key.length - 1)]];
    
    unsigned int count = self.trunk.count;
    Ivar *ivarList = self.trunk.ivarList;
    if(ivarList ==  nil) {
        ivarList = class_copyIvarList([self class], &count);
        self.trunk.ivarList = ivarList;
        self.trunk.count = count;
    }
    
    NSString *_key = [NSString stringWithFormat:@"_%@", key];
    NSString *isKey = [NSString stringWithFormat:@"is%@", upperFirsetCharKey];
    NSString *_isKey = [NSString stringWithFormat:@"_%@", isKey];
    Ivar foundedIvar = nil;
    
    for (int i = 0; i < count; i++) {
        Ivar ivar = ivarList[i];
        NSString *ivarName = @(ivar_getName(ivar));
        
        if ([ivarName isEqualToString:_key] || [ivarName isEqualToString:_isKey]  || [ivarName isEqualToString:key] || [ivarName isEqualToString:isKey]) {
            foundedIvar = ivar;
            break;
        }
    }
    
    if (foundedIvar) {
        uintptr_t offset = ivar_getOffset(foundedIvar);
        const char *typeEncoding = ivar_getTypeEncoding(foundedIvar);
        char type = typeEncoding[0];
        
        void *ivarPtr = (__bridge void *)self + offset;
        switch (type) {
            case 'B': { //BOOL
                BOOL *val = (BOOL *)ivarPtr;
                *val = [value boolValue];
                return YES;
                break;
            };
            case 'c': { //char
                char *val = (char *)ivarPtr;
                *val = [value charValue];
                return YES;
                break;
            };
            case 'C': { //unsigned char
                unsigned char *val = (unsigned char *)ivarPtr;
                *val = [value unsignedCharValue];
                return YES;
                break;
            };
            case 's': { //short
                short *val = (short *)ivarPtr;
                *val = [value shortValue];
                return YES;
                break;
            };
            case 'S': { //unsigned short
                unsigned short *val = (unsigned short *)ivarPtr;
                *val = [value unsignedShortValue];
                return YES;
                break;
            };
            case 'i': { //int
                int *val = (int *)ivarPtr;
                *val = [value intValue];
                return YES;
                break;
            };
            case 'I': { //unsigned int
                unsigned int *val = ivarPtr;
                *val = [value unsignedIntValue];
                return YES;
                break;
            };
            case 'l': { //long
                long *val = (long *)ivarPtr;
                *val = [value longValue];
                return YES;
                break;
            };
            case 'L': { //unsigned long
                unsigned long *val = (unsigned long *)ivarPtr;
                *val = [value unsignedLongValue];
                return YES;
                break;
            };
            case 'q': { //long long
                long long *val = (long long *)ivarPtr;
                *val = [value longLongValue];
                return YES;
                break;
            };
            case 'Q': { //unsigned long long
                unsigned long long *val = (unsigned long long *)ivarPtr;
                *val = [value unsignedLongLongValue];
                return YES;
                break;
            };
            case 'f': { //float
                float *val = (float *)ivarPtr;
                *val = [value floatValue];
                return YES;
                break;
            };
            case 'd': { //double
                double *val = (double *)ivarPtr;
                *val = [value doubleValue];
                return YES;
                break;
            };
            case 'D': { //long double
                //系统的kvc中不支持long double类型
                break;
            }
            case '@': { //id
                __strong id *val = (__strong id *)ivarPtr;
                *val = value;
                return YES;
                break;
            };
            case '#': { //Class
                __strong Class *val = (__strong Class *)ivarPtr;
                *val = value;
                return YES;
                break;
            };
            case '*': { // char *
                //系统的kvc中不支持char *
                break;
            }
            case '^':{ //pointer
                //系统的kvc中不支持pointer
                break;
            }
            case '{': { //结构体
                if ([value isKindOfClass:[NSValue class]] == NO) {
                    NSException *exception = [NSException exceptionWithName:@"value类型错误" reason:@"对结构体类型使用jk_setValue:forKey:方法，请确保传入的value类型是NSValue" userInfo:nil];
                    [exception raise];
                }
                
                NSUInteger size = 0;
                NSGetSizeAndAlignment(typeEncoding, &size, nil);
                Byte buffer[size];
                [(NSValue *)value getValue:buffer];
                memcpy(ivarPtr, buffer, size);
                return YES;
                break;
            };
            case '(': { //联合体
                //系统的kvc中不支持结构体
                break;
            };
            case '[': {// c数组
                //系统的kvc中不支持long double类型
                break;
            }
            default: { // unknown
                break;
            };
        }
    }
    
    return NO;
}
@end
