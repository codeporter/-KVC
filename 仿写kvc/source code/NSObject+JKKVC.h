//
//  NSObject+JKKVC.h
//  仿写kvc
//
//  Created by coder on 2019/10/9.
//  Copyright © 2019 coder. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (JKKVC)
@property (class, readonly) BOOL jk_accessInstanceVariablesDirectly;

- (id)jk_valueForKeyPath:(NSString *)keyPath;
- (id)jk_valueForKey:(NSString *)key;

- (void)jk_setValue:(id)value forKey:(NSString *)key;
- (void)jk_setValue:(id)value forKeyPath:(NSString *)keyPath;

@end

NS_ASSUME_NONNULL_END
