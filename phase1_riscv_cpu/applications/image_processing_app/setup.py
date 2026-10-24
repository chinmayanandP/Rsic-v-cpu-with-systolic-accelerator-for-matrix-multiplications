from setuptools import setup, find_packages

setup(
    name='jpeg_codec',
    version='0.1.0',
    author='BRlin',
    author_email='brend.main@gmail.com',
    description='一個JPEG編碼器和解碼器庫',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/JPEG',
    license='MIT',
    packages=find_packages(),
    install_requires=[
        'numpy',
        'opencv-python',
        'imageio',
        # 其他依賴
    ],
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
)
