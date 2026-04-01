package net.javaguides.springboot.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import net.javaguides.springboot.dto.UserRegistrationDto;
import net.javaguides.springboot.model.Role;
import net.javaguides.springboot.model.User;
import net.javaguides.springboot.repository.UserRepository;

@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

	@Mock
	private UserRepository userRepository;

	@Mock
	private BCryptPasswordEncoder passwordEncoder;

	private UserServiceImpl userService;

	@org.junit.jupiter.api.BeforeEach
	void setUp() {
		userService = new UserServiceImpl(userRepository);
		ReflectionTestUtils.setField(userService, "passwordEncoder", passwordEncoder);
	}

	@Test
	void saveCreatesUserWithEncodedPasswordAndDefaultRole() {
		UserRegistrationDto registrationDto = new UserRegistrationDto("Ada", "Lovelace", "ada@example.com", "plain-secret");
		User savedUser = new User();
		when(passwordEncoder.encode("plain-secret")).thenReturn("encoded-secret");
		when(userRepository.save(any(User.class))).thenReturn(savedUser);

		User result = userService.save(registrationDto);

		assertThat(result).isSameAs(savedUser);
		ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
		verify(userRepository).save(userCaptor.capture());
		User capturedUser = userCaptor.getValue();
		assertThat(capturedUser.getFirstName()).isEqualTo("Ada");
		assertThat(capturedUser.getLastName()).isEqualTo("Lovelace");
		assertThat(capturedUser.getEmail()).isEqualTo("ada@example.com");
		assertThat(capturedUser.getPassword()).isEqualTo("encoded-secret");
		assertThat(capturedUser.getRoles()).extracting(Role::getName).containsExactly("ROLE_USER");
	}

	@Test
	void loadUserByUsernameReturnsSpringSecurityUser() {
		User user = new User("Ada", "Lovelace", "ada@example.com", "hashed-password",
			List.of(new Role("ROLE_USER"), new Role("ROLE_ADMIN")));
		when(userRepository.findByEmail("ada@example.com")).thenReturn(user);

		UserDetails userDetails = userService.loadUserByUsername("ada@example.com");

		assertThat(userDetails.getUsername()).isEqualTo("ada@example.com");
		assertThat(userDetails.getPassword()).isEqualTo("hashed-password");
		assertThat(userDetails.getAuthorities())
			.extracting(GrantedAuthority::getAuthority)
			.containsExactlyInAnyOrder("ROLE_USER", "ROLE_ADMIN");
	}

	@Test
	void loadUserByUsernameThrowsWhenUserMissing() {
		when(userRepository.findByEmail("missing@example.com")).thenReturn(null);

		assertThatThrownBy(() -> userService.loadUserByUsername("missing@example.com"))
			.isInstanceOf(UsernameNotFoundException.class)
			.hasMessage("Invalid username or password.");
	}
}
