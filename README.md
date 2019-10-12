# 仿写KVC - 自己实现一个可用的KVC

## 实现思路

### -(id)valueForKey:(NSString *)key方法的实现

系统的方法中针对NSArray和NSSet集合类也做了处理，我这里去掉了这部分逻辑。大致查找过程如下：

假设传入的key名称为`name`

1. 首先查看是否有getName, name, isName, \_name方法，如果有直接通过对应的方法获取返回值，如果返回值是标量类型(int,float等)，包装成NSNumber或者NSValue类型；如果没找到方法跳到第2步。
2. 判断是否开启accessInstanceVariablesDirectly，如果为YES，进入第3步；否则进入第4步
3. 查找是否有\_name, \_isName, name, isName 成员变量，如果有则通过对象的地址+成员变量的偏移量获取对应的数据，同样将标量类型进行包装；如果没有找到成员变量进入第三步。
4. 调用valueForUndefinedKey:来抛出异常。

首先是获取对应方法的IMP指针，然后通过NSMethodSignature获取方法签名，这样就拿到了返回值类型，对于int,float标量类型就包装成NSNumber返回，结构体包装成NSValue返回。如果没有对应的getter方法，则获取对应类的ivarList，拿到typeEncoding和偏移量，通过偏移量获取成员变量的地址，并根据typeEncoding解析数据类型取值，同样非对象类型包装成对应的Obejct返回。

### - (void)setValue:(id)value forKey:(NSString *)key方法的实现
同样假设传入的key名称为`name`

1. 首先查看是否有setName:, \_setName: 方法，如果有直接通过对应的方法赋值，如果成员变量是标量类型(int,float等)，则将传入的参数value解包成对应类型数据；如果没找到方法跳到第2步。
2. 判断是否开启accessInstanceVariablesDirectly，如果为YES，进入第3步；否则进入第4步
3. 查找是否有\_name, \_isName, name, isName成员变量，如果有则通过对象的地址+成员变量的偏移量获取成员变量的地址，同样将参数value解包成对应数据类型；如果没有找到成员变量进入第4步。
4. 调用setValue:forUndefinedKey:来抛出异常

首先获取对应的setter方法的IMP指针，然后通过NSMethodSignature获取方法签名，获取setter方法参数的类型，对于参数是结构体类型通过NSGetSizeAndAlignment方法获取类型size，然后构建buffer，将value当成NSValue类型填充buffer数据，然后通过NSInvocation调用setter方法。如果没有对应的setter方法，则获取对应类的ivarList，拿到typeEncoding和偏移量，通过偏移量获取成员变量的地址并转换成对应类型的指针，然后将value解包成对应类型赋值。

另外，系统的kvc中不支持 `long double`,`char *`, `void *`, `union`, `c数组`等类型，所以在我的实现中也跟系统保持一致，判断出是该类型直接抛出异常。
